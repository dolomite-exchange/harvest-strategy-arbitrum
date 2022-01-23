pragma solidity ^0.5.16;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../../../base/interface/curve/IGauge.sol";
import "../../../base/interface/curve/ICurveDeposit_2token.sol";
import "../../../base/interface/uniswap/IUniswapV2Router02.sol";
import "../../../base/interface/IStrategy.sol";
import "../../../base/interface/IVault.sol";

import "../../../base/StrategyBase.sol";

/**
* This strategy is for the mixToken vault, i.e., the underlying token is mixToken. It is not to accept
* stable coins. It will farm the CRV crop. For liquidation, it swaps CRV into EURS and uses EURS
* to produce mixToken.
*/
contract CRVStrategyEURS is StrategyBase {

  using SafeERC20 for IERC20;
  using Address for address;
  using SafeMath for uint256;

  event Liquidating(uint256 amount);
  event ProfitsNotCollected();

  // crvEURS
  address public pool;
  address public mintr;
  address public crv;

  address public weth;
  address public usdc;
  address public eurs;
  address public curveDepositEURS;

  address public uni;

  uint256 maxUint = uint256(~0);
  address[] public uniswap_CRV2EURS;

  // a flag for disabling selling for simplified emergency exit
  bool public sell = true;
  // minimum CRV amount to be liquidation
  uint256 public sellFloor = 1e18;

  constructor(
    address _storage,
    address _vault,
    address _underlying,
    address _gauge,
    address _mintr,
    address _crv,
    address _weth,
    address _usdc,
    address _eurs,
    address _curveDepositEURS,
    address _uniswap
  )
  StrategyBase(_storage, _underlying, _vault, _crv, _uniswap) public {
    require(IVault(_vault).underlying() == _underlying, "vault does not support eursCRV");
    pool = _gauge;
    mintr = _mintr;
    crv = _crv;
    weth = _weth;
    usdc = _usdc;
    eurs = _eurs;
    curveDepositEURS = _curveDepositEURS;
    uni = _uniswap;
    uniswap_CRV2EURS = [crv, weth, usdc, eurs];
  }

  function depositArbCheck() public view returns(bool) {
    return true;
  }

  /**
  * Withdraws underlying from the investment pool that mints crops.
  */
  function withdrawUnderlyingFromPool(uint256 amount) internal {
    IGauge(pool).withdraw(
      Math.min(IGauge(pool).balanceOf(address(this)), amount)
    );
  }

  /**
  * Withdraws the underlying tokens to the pool in the specified amount.
  */
  function withdrawToVault(uint256 amountUnderlying) external restricted {
    withdrawUnderlyingFromPool(amountUnderlying);
    require(IERC20(underlying).balanceOf(address(this)) >= amountUnderlying, "insufficient balance for the withdrawal");
    IERC20(underlying).safeTransfer(vault, amountUnderlying);
  }

  /**
  * Withdraws all the underlying tokens to the pool.
  */
  function withdrawAllToVault() external restricted {
    claimAndLiquidateCrv();
    withdrawUnderlyingFromPool(maxUint);
    uint256 balance = IERC20(underlying).balanceOf(address(this));
    IERC20(underlying).safeTransfer(vault, balance);
  }

  /**
  * Invests all the underlying into the pool that mints crops (CRV)
  */
  function investAllUnderlying() public restricted {
    uint256 underlyingBalance = IERC20(underlying).balanceOf(address(this));
    if (underlyingBalance > 0) {
      IERC20(underlying).safeApprove(pool, 0);
      IERC20(underlying).safeApprove(pool, underlyingBalance);
      IGauge(pool).deposit(underlyingBalance);
    }
  }

  /**
  * Claims the CRV crop, converts it to EURS on Uniswap, and then uses EURS to mint underlying using the
  * Curve protocol.
  */
  function claimAndLiquidateCrv() internal {
    if (!sell) {
      // Profits can be disabled for possible simplified and rapid exit
      emit ProfitsNotCollected();
      return;
    }
    Mintr(mintr).mint(pool);

    uint256 rewardBalance = IERC20(crv).balanceOf(address(this));
    if (rewardBalance < sellFloor) {
      // Profits can be disabled for possible simplified and rapid exit
      emit ProfitsNotCollected();
      return;
    }

    notifyProfitInRewardToken(rewardBalance);
    uint256 crvBalance = IERC20(crv).balanceOf(address(this));

    if (crvBalance > 0) {
      emit Liquidating(crvBalance);
      IERC20(crv).safeApprove(uni, 0);
      IERC20(crv).safeApprove(uni, crvBalance);
      // we can accept 1 as the minimum because this will be called only by a trusted worker
      IUniswapV2Router02(uni).swapExactTokensForTokens(
        crvBalance, 1, uniswap_CRV2EURS, address(this), block.timestamp
      );

      if(IERC20(eurs).balanceOf(address(this)) > 0) {
        eursCRVFromEurs();
      }
    }
  }

  /**
  * Claims and liquidates CRV into underlying, and then invests all underlying.
  */
  function doHardWork() public restricted {
    claimAndLiquidateCrv();
    investAllUnderlying();
  }

  /**
  * Investing all underlying.
  */
  function investedUnderlyingBalance() public view returns (uint256) {
    return IGauge(pool).balanceOf(address(this)).add(
      IERC20(underlying).balanceOf(address(this))
    );
  }

  /**
  * Converts all EURS to underlying using the CRV protocol.
  */
  function eursCRVFromEurs() internal {
    uint256 eursBalance = IERC20(eurs).balanceOf(address(this));
    if (eursBalance > 0) {
      IERC20(eurs).safeApprove(curveDepositEURS, 0);
      IERC20(eurs).safeApprove(curveDepositEURS, eursBalance);

      // we can accept 0 as minimum, this will be called only by trusted roles
      uint256 minimum = 0;
      ICurveDeposit_2token(curveDepositEURS).add_liquidity([eursBalance, 0], minimum);
      // now we have eursCRV
    }
  }

  /**
  * Can completely disable claiming CRV rewards and selling. Good for emergency withdraw in the
  * simplest possible way.
  */
  function setSell(bool s) public onlyGovernance {
    sell = s;
  }

  /**
  * Sets the minimum amount of CRV needed to trigger a sale.
  */
  function setSellFloor(uint256 floor) public onlyGovernance {
    sellFloor = floor;
  }
}
