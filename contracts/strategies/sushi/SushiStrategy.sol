pragma solidity ^0.5.16;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "../../base/interfaces/uniswap/IUniswapV2Pair.sol";
import "../../base/interfaces/uniswap/IUniswapV2Router02.sol";
import "../../base/interfaces/IStrategy.sol";
import "../../base/upgradability/BaseUpgradeableStrategy.sol";

import "./interfaces/IMiniChefV2.sol";


contract SushiStrategy is IStrategy, BaseUpgradeableStrategy {
    using SafeMath for uint256;

    // additional storage slots (on top of BaseUpgradeableStrategy ones) are defined here
    bytes32 internal constant _PID_SLOT = 0x12e751858fa565f6e661164a3bc9328779f969ad22fbb6e0eaa6447021e5dbfb;

    constructor() public BaseUpgradeableStrategy() {
        assert(_PID_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.pid")) - 1));
    }

    function initializeSushiStrategy(
        address _storage,
        address _underlying,
        address _vault,
        address _rewardPool,
        address[] memory _rewardTokens,
        address _strategist,
        uint256 _pid
    ) public initializer {
        BaseUpgradeableStrategy.initialize(
            _storage,
            _underlying,
            _vault,
            _rewardPool,
            _rewardTokens,
            _strategist
        );

        require(
            IMiniChefV2(rewardPool()).lpToken(_pid) == underlying(),
            "pool lpToken does not match underlying"
        );

        IERC20(underlying()).safeApprove(rewardPool(), uint(-1));

        IUniswapV2Pair pair = IUniswapV2Pair(underlying());
        IERC20(pair.token0()).safeApprove(SUSHI_ROUTER, uint(-1));
        IERC20(pair.token1()).safeApprove(SUSHI_ROUTER, uint(-1));

        _setPid(_pid);
    }

    function depositArbCheck() external view returns(bool) {
        return true;
    }

    function pid() public view returns (uint256) {
        return getUint256(_PID_SLOT);
    }

    function getRewardPoolValues() public returns (uint256[] memory values) {
        values = new uint256[](1);
        values[0] = IMiniChefV2(rewardPool()).pendingSushi(pid(), address(this));
    }

    // ========================= Internal Functions =========================

    function _setPid(uint256 _pid) internal {
        setUint256(_PID_SLOT, _pid);
    }

    function _finalizeUpgrade() internal {}

    function _rewardPoolBalance() internal view returns (uint256 balance) {
        (balance,) = IMiniChefV2(rewardPool()).userInfo(pid(), address(this));
    }

    function _partialExitRewardPool(uint256 _amount) internal {
        if (_amount > 0) {
            IMiniChefV2(rewardPool()).withdrawAndHarvest(pid(), _amount, address(this));
        }
    }

    function _enterRewardPool() internal {
        address user = address(this);
        uint256 entireBalance = IERC20(underlying()).balanceOf(user);
        // allowance is already set in initializer
        IMiniChefV2(rewardPool()).deposit(pid(), entireBalance, user); // deposit and stake
    }

    function _claimRewards() internal {
        IMiniChefV2(rewardPool()).harvest(pid(), address(this));
    }

    function _liquidateReward() internal {
        IUniswapV2Pair pair = IUniswapV2Pair(underlying());
        address[] memory _rewardTokens = rewardTokens();
        for (uint i = 0; i < _rewardTokens.length; i++) {
            uint256 rewardBalance = IERC20(_rewardTokens[i]).balanceOf(address(this));
            address[] memory buybackTokens = new address[](2);
            buybackTokens[0] = pair.token0();
            buybackTokens[1] = pair.token1();

            _notifyProfitAndBuybackInRewardToken(_rewardTokens[i], rewardBalance, buybackTokens);

            uint256 tokenBalance0 = IERC20(buybackTokens[0]).balanceOf(address(this));
            uint256 tokenBalance1 = IERC20(buybackTokens[1]).balanceOf(address(this));
            if (tokenBalance0 > 0 && tokenBalance1 > 0) {
                _mintLiquidityTokens();
                _enterRewardPool();
            }
        }
    }

    function _mintLiquidityTokens() internal {
        IUniswapV2Pair pair = IUniswapV2Pair(underlying());
        address token0 = pair.token0();
        address token1 = pair.token1();

        address user = address(this);
        uint256 tokenBalance0 = IERC20(token0).balanceOf(user);
        uint256 tokenBalance1 = IERC20(token1).balanceOf(user);
        // Approval was already done in initializer
        // amountAMin and amountBMin are set to 50% of the balance of each. This is called by a trusted role anyway.
        IUniswapV2Router02(SUSHI_ROUTER).addLiquidity(
            token0,
            token1,
            tokenBalance0,
            tokenBalance1,
            tokenBalance0 * 5 / 10,
            tokenBalance1 * 5 / 10,
            user,
            uint(-1)
        );

        uint unweightedNumerator = 3;
        uint unweightedDenominator = 4;
        uint256 newTokenBalance0 = IERC20(token0).balanceOf(user);
        uint256 newTokenBalance1 = IERC20(token1).balanceOf(user);
        if (newTokenBalance0 > tokenBalance0 * 2 / 10) {
            // There is still 20% of the balance sitting in here. Let's sell 3/4. We can compound it after the next
            // doHardWork
            // This happens when we get better price execution for token0 vs token1, making the balances "unweighted"
            address[] memory buybackTokens = new address[](1);
            buybackTokens[0] = token1;
            _notifyProfitAndBuybackInRewardToken(
                token0,
                newTokenBalance0 * unweightedNumerator / unweightedDenominator,
                buybackTokens
            );
        } else if (newTokenBalance1 > tokenBalance1 * 2 / 10) {
            // There is still 20% of the balance sitting in here. Let's sell some. We can compound it after the next
            // doHardWork
            // This happens when we get better price execution for token1 vs token0, making the balances "unweighted"
            address[] memory buybackTokens = new address[](1);
            buybackTokens[0] = token0;
            _notifyProfitAndBuybackInRewardToken(
                token1,
                newTokenBalance1 * unweightedNumerator / unweightedDenominator,
                buybackTokens
            );
        }
    }
}
