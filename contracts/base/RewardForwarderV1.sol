pragma solidity ^0.5.16;

import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "./inheritance/Governable.sol";
import "./interfaces/IRewardForwarder.sol";
import "./interfaces/IPotPool.sol";
import "./interfaces/IStrategy.sol";
import "./interfaces/IUniversalLiquidator.sol";
import "./interfaces/uniswap/IUniswapV2Router02.sol";
import "./inheritance/Controllable.sol";
import "./inheritance/Constants.sol";


/**
 * @dev This contract receives rewards from strategies and is responsible for routing the reward's liquidation into
 *      specific buyback tokens and profit tokens for the DAO.
 */
contract RewardForwarderV1 is IRewardForwarder, Controllable, Constants {
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
        uint256 _profitSharingFee,
        uint256 _strategistFee,
        uint256 _platformFee,
        address[] calldata _buybackTokens,
        uint256[] calldata _buybackAmounts
    ) external returns (uint[] memory) {
        return _notifyFeeAndBuybackAmounts(
            _token,
            _profitSharingFee,
            _strategistFee,
            _platformFee,
            _buybackTokens,
            _buybackAmounts
        );
    }

    function notifyFee(
        address _token,
        uint256 _profitSharingFee,
        uint256 _strategistFee,
        uint256 _platformFee
    ) external {
        _notifyFeeAndBuybackAmounts(
            _token,
            _profitSharingFee,
            _strategistFee,
            _platformFee,
            new address[](0),
            new uint256[](0)
        );
    }

    function _notifyFeeAndBuybackAmounts(
        address _token,
        uint256 _profitSharingFee,
        uint256 _strategistFee,
        uint256 _platformFee,
        address[] memory _buybackTokens,
        uint256[] memory _buybackAmounts
    ) internal returns (uint[] memory) {
        address _controller = controller();
        require(
            IController(_controller).hasStrategy(msg.sender),
            "msg.sender must be a strategy"
        );

        address liquidator = IController(_controller).universalLiquidator();
        {
            uint totalTransferAmount = _profitSharingFee.add(_strategistFee).add(_platformFee);
            for (uint i = 0; i < _buybackAmounts.length; i++) {
                totalTransferAmount = totalTransferAmount.add(_buybackAmounts[i]);
            }
            require(totalTransferAmount > 0, "totalTransferAmount should not be 0");
            IERC20(_token).safeTransferFrom(msg.sender, address(this), totalTransferAmount);

            IERC20(_token).safeApprove(liquidator, 0);
            IERC20(_token).safeApprove(liquidator, totalTransferAmount);
        }

        uint amountOutMin = 1;

        if (_strategistFee > 0) {
            IUniversalLiquidator(liquidator).swapTokens(
                _token,
                targetToken,
                _strategistFee,
                amountOutMin,
                IStrategy(msg.sender).strategist()
            );
        }
        if (_platformFee > 0) {
            IUniversalLiquidator(liquidator).swapTokens(
                _token,
                targetToken,
                _platformFee,
                amountOutMin,
                IController(_controller).governance()
            );
        }
        if (_profitSharingFee > 0) {
            IUniversalLiquidator(liquidator).swapTokens(
                _token,
                targetToken,
                _profitSharingFee,
                amountOutMin,
                profitSharingPool
            );
        }

        uint[] memory amounts = new uint[](_buybackTokens.length);
        for (uint i = 0; i < amounts.length; ++i) {
            if (_buybackAmounts[i] > 0) {
                amounts[i] = IUniversalLiquidator(liquidator).swapTokens(
                    _token,
                    _buybackTokens[i],
                    _buybackAmounts[i],
                    amountOutMin,
                    msg.sender
                );
            }
        }

        return amounts;
    }
}
