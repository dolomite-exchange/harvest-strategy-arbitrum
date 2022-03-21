pragma solidity ^0.5.16;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../../../base/interfaces/uniswap/IUniswapV2Router02.sol";
import "../../../base/interfaces/IStrategy.sol";
import "../../../base/interfaces/IVault.sol";
import "../../../base/upgradability/BaseUpgradeableStrategy.sol";
import "../../../base/interfaces/uniswap/IUniswapV2Pair.sol";
import "../interfaces/IBooster.sol";
import "../interfaces/IBaseRewardPool.sol";
import "../../../base/interfaces/curve/ICurveDeposit_2token.sol";

contract ConvexStrategy2Token is IStrategy, BaseUpgradeableStrategy {

    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public constant uniswapRouterV2 = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    address public constant sushiswapRouterV2 = address(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);
    address public constant booster = address(0xF403C135812408BFbE8713b5A23a04b3D48AAE31);
    address public constant weth = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

    // additional storage slots (on top of BaseUpgradeableStrategy ones) are defined here
    bytes32 internal constant _POOL_ID_SLOT = 0x3fd729bfa2e28b7806b03a6e014729f59477b530f995be4d51defc9dad94810b;
    bytes32 internal constant _DEPOSIT_TOKEN_SLOT = 0x219270253dbc530471c88a9e7c321b36afda219583431e7b6c386d2d46e70c86;
    bytes32 internal constant _DEPOSIT_RECEIPT_SLOT = 0x414478d5ad7f54ead8a3dd018bba4f8d686ba5ab5975cd376e0c98f98fb713c5;
    bytes32 internal constant _DEPOSIT_ARRAY_POSITION_SLOT = 0xb7c50ef998211fff3420379d0bf5b8dfb0cee909d1b7d9e517f311c104675b09;
    bytes32 internal constant _CURVE_DEPOSIT_SLOT = 0xb306bb7adebd5a22f5e4cdf1efa00bc5f62d4f5554ef9d62c1b16327cd3ab5f9;

    constructor() public BaseUpgradeableStrategy() {
        assert(_POOL_ID_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.poolId")) - 1));
        assert(_DEPOSIT_TOKEN_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.depositToken")) - 1));
        assert(_DEPOSIT_RECEIPT_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.depositReceipt")) - 1));
        assert(_DEPOSIT_ARRAY_POSITION_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.depositArrayPosition")) - 1));
        assert(_CURVE_DEPOSIT_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.curveDeposit")) - 1));
    }

    function initializeBaseStrategy(
        address _storage,
        address _underlying,
        address _vault,
        address _rewardPool,
        address _strategist,
        uint256 _poolID,
        address _depositToken,
        uint256 _depositArrayPosition,
        address _curveDeposit
    ) public initializer {
        address[] memory rewardTokens = new address[](1);
        rewardTokens[0] = WETH;

        BaseUpgradeableStrategy.initialize(
            _storage,
            _underlying,
            _vault,
            _rewardPool,
            rewardTokens,
            _strategist
        );

        address _lpt;
        address _depositReceipt;
        (_lpt, _depositReceipt,,,,) = IBooster(booster).poolInfo(_poolID);
        require(_lpt == underlying(), "Pool Info does not match underlying");
        require(_depositArrayPosition < 2, "Deposit array position out of bounds");
        _setDepositArrayPosition(_depositArrayPosition);
        _setPoolId(_poolID);
        _setDepositToken(_depositToken);
        _setDepositReceipt(_depositReceipt);
        _setCurveDeposit(_curveDeposit);
    }

    function depositArbCheck() public view returns (bool) {
        return true;
    }

    function rewardPoolBalance() internal view returns (uint256 bal) {
        bal = IBaseRewardPool(rewardPool()).balanceOf(address(this));
    }

    function exitRewardPool() internal {
        uint256 stakedBalance = rewardPoolBalance();
        if (stakedBalance != 0) {
            IBaseRewardPool(rewardPool()).withdrawAll(true);
        }
        uint256 depositBalance = IERC20(depositReceipt()).balanceOf(address(this));
        if (depositBalance != 0) {
            IBooster(booster).withdrawAll(poolId());
        }
    }

    function partialWithdrawalRewardPool(uint256 amount) internal {
        IBaseRewardPool(rewardPool()).withdraw(amount, false);
        //don't claim rewards at this point
        uint256 depositBalance = IERC20(depositReceipt()).balanceOf(address(this));
        if (depositBalance != 0) {
            IBooster(booster).withdrawAll(poolId());
        }
    }

    function emergencyExitRewardPool() internal {
        uint256 stakedBalance = rewardPoolBalance();
        if (stakedBalance != 0) {
            IBaseRewardPool(rewardPool()).withdrawAll(false);
            //don't claim rewards
        }
        uint256 depositBalance = IERC20(depositReceipt()).balanceOf(address(this));
        if (depositBalance != 0) {
            IBooster(booster).withdrawAll(poolId());
        }
    }

    function isUnsalvageableToken(address _token) public view returns (bool) {
        return super.isUnsalvageableToken(_token) || _token == depositReceipt();
    }

    function _enterRewardPool() internal {
        uint256 entireBalance = IERC20(underlying()).balanceOf(address(this));
        IERC20(underlying()).safeApprove(booster, 0);
        IERC20(underlying()).safeApprove(booster, entireBalance);
        IBooster(booster).depositAll(poolId(), true);
        //deposit and stake
    }

    /*
    *   In case there are some issues discovered about the pool or underlying asset
    *   Governance can exit the pool properly
    *   The function is only used for emergency to exit the pool
    */
    function emergencyExit() public onlyGovernance {
        emergencyExitRewardPool();
        _setPausedInvesting(true);
    }

    /*
    *   Resumes the ability to invest into the underlying reward pools
    */

    function continueInvesting() public onlyGovernance {
        _setPausedInvesting(false);
    }

    function _liquidateReward() internal {
        address[] memory _rewardTokens = rewardTokens();
        for (uint i = 0; i < _rewardTokens.length; i++) {
            uint256 rewardBalance = IERC20(_rewardTokens[i]).balanceOf(address(this));
            if (!sell() || rewardBalance < sellFloor()) {
                emit ProfitsNotCollected(_rewardTokens[i], sell(), rewardBalance < sellFloor());
                return;
            }

            address[] memory buybackTokens = new address[](1);
            buybackTokens[0] = depositToken();

            _notifyProfitAndBuybackInRewardToken(_rewardTokens[i], rewardBalance, buybackTokens);

            uint256 tokenBalance = IERC20(depositToken()).balanceOf(address(this));
            if (tokenBalance > 0) {
                depositCurve();
            }
        }
    }

    function depositCurve() internal {
        uint256 tokenBalance = IERC20(depositToken()).balanceOf(address(this));
        IERC20(depositToken()).safeApprove(curveDeposit(), 0);
        IERC20(depositToken()).safeApprove(curveDeposit(), tokenBalance);

        uint256[2] memory depositArray;
        depositArray[depositArrayPosition()] = tokenBalance;

        // we can accept 0 as minimum, this will be called only by trusted roles
        uint256 minimum = 0;
        ICurveDeposit_2token(curveDeposit()).add_liquidity(depositArray, minimum);
    }

    /**
     * Stakes everything the strategy holds into the reward pool
     */
    function investAllUnderlying() internal onlyNotPausedInvesting {
        // this check is needed, because most of the SNX reward pools will revert if
        // you try to stake(0).
        if (IERC20(underlying()).balanceOf(address(this)) > 0) {
            _enterRewardPool();
        }
    }

    /**
     * Withdraws all the asset to the vault
     */
    function withdrawAllToVault() public restricted {
        if (address(rewardPool()) != address(0)) {
            exitRewardPool();
        }
        _liquidateReward();
        IERC20(underlying()).safeTransfer(vault(), IERC20(underlying()).balanceOf(address(this)));
    }

    /**
     *   Withdraws all the asset to the vault
     */
    function withdrawToVault(uint256 amount) public restricted {
        // Typically there wouldn't be any amount here
        // however, it is possible because of the emergencyExit
        uint256 entireBalance = IERC20(underlying()).balanceOf(address(this));

        if (amount > entireBalance) {
            // While we have the check above, we still using SafeMath below
            // for the peace of mind (in case something gets changed in between)
            uint256 needToWithdraw = amount.sub(entireBalance);
            uint256 toWithdraw = Math.min(rewardPoolBalance(), needToWithdraw);
            partialWithdrawalRewardPool(toWithdraw);
        }
        IERC20(underlying()).safeTransfer(vault(), amount);
    }

    /**
     * Note that we currently do not have a mechanism here to include the amount of reward that is accrued.
     */
    function investedUnderlyingBalance() external view returns (uint256) {
        return rewardPoolBalance()
        .add(IERC20(depositReceipt()).balanceOf(address(this)))
        .add(IERC20(underlying()).balanceOf(address(this)));
    }

    function doHardWork() external onlyNotPausedInvesting restricted {
        IBaseRewardPool(rewardPool()).getReward();
        _liquidateReward();
        investAllUnderlying();
    }

    function _setPoolId(uint256 _value) internal {
        setUint256(_POOL_ID_SLOT, _value);
    }

    function poolId() public view returns (uint256) {
        return getUint256(_POOL_ID_SLOT);
    }

    function _setDepositToken(address _address) internal {
        setAddress(_DEPOSIT_TOKEN_SLOT, _address);
    }

    function depositToken() public view returns (address) {
        return getAddress(_DEPOSIT_TOKEN_SLOT);
    }

    function  _setDepositReceipt(address _address) internal {
        setAddress(_DEPOSIT_RECEIPT_SLOT, _address);
    }

    function depositReceipt() public view returns (address) {
        return getAddress(_DEPOSIT_RECEIPT_SLOT);
    }

    function _setDepositArrayPosition(uint256 _value) internal {
        setUint256(_DEPOSIT_ARRAY_POSITION_SLOT, _value);
    }

    function depositArrayPosition() public view returns (uint256) {
        return getUint256(_DEPOSIT_ARRAY_POSITION_SLOT);
    }

    function _setCurveDeposit(address _address) internal {
        setAddress(_CURVE_DEPOSIT_SLOT, _address);
    }

    function curveDeposit() public view returns (address) {
        return getAddress(_CURVE_DEPOSIT_SLOT);
    }

    function finalizeUpgrade() external onlyGovernance {
        _finalizeUpgrade();
    }
}
