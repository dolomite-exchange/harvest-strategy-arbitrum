pragma solidity ^0.5.16;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "./inheritance/Governable.sol";
import "./interfaces/IRewardForwarder.sol";
import "./interfaces/IPotPool.sol";
import "./interfaces/IUniversalLiquidator.sol";
import "./interfaces/uniswap/IUniswapV2Router02.sol";
import "./inheritance/Controllable.sol";
import "./inheritance/Constants.sol";


/**
 * @dev This contract receives rewards from strategies and is responsible for routing the reward's liquidation into
 *      specific buyback tokens and profit tokens for the DAO.
 */
contract RewardForwarder is IRewardForwarder, Controllable, Constants {
    using SafeERC20 for IERC20;
    using SafeMath for uint256;

    /// @notice the targeted reward token to convert everything to
    address public targetToken;
    address public profitSharingPool;

    event ProfitSharingPoolSet(address token, address pool);

    constructor(
        address _storage,
        address _targetToken,
        address _profitSharingPool
    ) public Controllable(_storage) {
        targetToken = _targetToken;
        profitSharingPool = _profitSharingPool;
    }

    /**
     * @notice Set the pool that will receive the reward token based on the address of the reward Token
     */
    function setProfitSharingPool(address _profitSharingPool) public onlyGovernance {
        require(
            IPotPool(_profitSharingPool).getRewardTokenIndex(targetToken) != uint(- 1),
            "The PotPool does not contain targetToken"
        );

        profitSharingPool = _profitSharingPool;
        emit ProfitSharingPoolSet(targetToken, _profitSharingPool);
    }

    function notifyFeeAndBuybackAmounts(
        address _token,
        uint256 _feeAmount,
        address[] calldata _buybackTokens,
        uint256[] calldata _buybackAmounts
    ) external returns (uint[] memory) {
        require(
            IController(controller()).hasStrategy(msg.sender),
            "sender must be a strategy"
        );

        uint totalTransferAmount = _feeAmount;
        for (uint i = 0; i < _buybackAmounts.length; i++) {
            totalTransferAmount = totalTransferAmount.add(_buybackAmounts[i]);
        }
        IERC20(_token).safeTransferFrom(msg.sender, address(this), totalTransferAmount);

        address liquidator = IController(controller()).universalLiquidator();
        uint amountOutMin = 1;

        // TODO if performance fees are added, get the strategy's reward recipient and send the appropriate amount to
        // TODO there and send the remaining amount to the profitSharingPool
        IUniversalLiquidator(liquidator).swapTokens(
            _feeAmount,
            amountOutMin,
            _token,
            targetToken,
            profitSharingPool
        );

        uint[] memory amounts = new uint[](_buybackTokens.length);
        for (uint i = 0; i < amounts.length; i++) {
            amounts[i] = IUniversalLiquidator(liquidator).swapTokens(
                _buybackAmounts[i],
                amountOutMin,
                _token,
                _buybackTokens[i],
                msg.sender
            );
        }

        return amounts;
    }
}
