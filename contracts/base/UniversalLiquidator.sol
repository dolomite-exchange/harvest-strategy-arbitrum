pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "./inheritance/Constants.sol";
import "./inheritance/ControllableInit.sol";
import "./interface/IController.sol";
import "./interface/IUpgradeSource.sol";
import "./interface/IUniversalLiquidator.sol";
import "./interface/uniswap/IUniswapV2Router02.sol";
import "./upgradability/BaseUpgradeableStrategyStorage.sol";


/**
 * @dev This contract can be redeployed many times, as new routers are added into `Constants.sol` since fields are added
 *      via slots.
 */
contract UniversalLiquidator is Initializable, BaseUpgradeableStrategyStorage, Constants, IUniversalLiquidator {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // ==================== Constants ====================

    bytes32 internal constant _PATH_TO_ROUTER_MAP_SLOT = 0xec75aba63bae097c93338983427905512acbafbbc4eeae15ba15b9aa6496e824;
    bytes32 internal constant _PATH_MAP_SLOT = 0x0e02e180b6adbb3b4f2512fc78c9b64fc852c781e663bd17448786d7fe4d2252;

    // ==================== Modifiers ====================

    modifier restricted() {
        require(msg.sender == controller() || msg.sender == governance(),
            "The sender has to be the controller, governance, or vault");
        _;
    }

    constructor() public {
        assert(_PATH_TO_ROUTER_MAP_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.pathToRouterMap")) - 1));
        assert(_PATH_MAP_SLOT == bytes32(uint256(keccak256("eip1967.strategyStorage.pathMap")) - 1));
    }

    // ==================== Events ====================

    event SwapConfigured(address inputToken, address outputToken, address router, address[] path);

    // ==================== Functions ====================

    function initialize(
        address _storage
    ) public initializer {
        ControllableInit.initialize(_storage);
    }

    function shouldUpgrade() public view returns (bool, address) {
        return (nextImplementation() != address(0), nextImplementation());
    }

    function finalizeUpgrade() public {
        // do nothing
    }

    function configureSwap(
        address[] calldata path,
        address router
    ) external onlyGovernance {
        _configureSwap(path, router);
    }

    function configureSwaps(
        address[][] memory paths,
        address[] memory routers
    ) public onlyGovernance {
        require(paths.length == routers.length, "invalid paths or routers length");
        for (uint i = 0; i < routers.length; i++) {
            _configureSwap(paths[i], routers[i]);
        }
    }

    function getSwapRouter(address inputToken, address outputToken) public view returns (address router) {
        bytes32 slot = _getSlotForRouter(inputToken, outputToken);
        // solhint-disable-next-line no-inline-assembly
        assembly {
            router := sload(slot)
        }
    }

    function swapTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address tokenIn,
        address tokenOut,
        address recipient
    ) external returns (uint) {
        require(
            msg.sender == IController(controller()).feeRewardForwarder(),
            "only callable from fee reward forwarder"
        );

        address router = getAddress(_getSlotForRouter(tokenIn, tokenOut));
        require(
            router != address(0),
            "invalid router for path"
        );

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);
        if (IERC20(tokenIn).allowance(address(this), router) < amountIn) {
            IERC20(tokenIn).safeApprove(router, 0);
            IERC20(tokenIn).safeApprove(router, amountIn);
        }

        return _performSwap(
            router,
            getAddressArray(_getSlotForPath(tokenIn, tokenOut)),
            amountIn,
            amountOutMin,
            recipient
        );
    }

    function _performSwap(
        address router,
        address[] memory path,
        uint amountIn,
        uint amountOutMin,
        address recipient
    ) internal returns (uint amountOut) {
        // TODO add Dolomite router
        if (router == SUSHI_ROUTER) {
            amountOut = IUniswapV2Router02(router).swapExactTokensForTokens(
                amountIn,
                amountOutMin,
                path,
                recipient,
                block.timestamp
            )[path.length - 1];
        } else {
            revert("unknown router");
        }
    }

    function _configureSwap(
        address[] memory path,
        address router
    ) internal {
        require(
            path.length >= 2,
            "invalid path length, expected >= 2"
        );
        setAddressArray(_getSlotForPath(path[0], path[path.length - 1]), path);
        setAddress(_getSlotForRouter(path[0], path[path.length - 1]), router);
        emit SwapConfigured(path[0], path[path.length - 1], router, path);
    }

    function _getSlotForPath(address inputToken, address outputToken) internal pure returns (bytes32) {
        bytes32 valueSlot = keccak256(abi.encodePacked(inputToken, outputToken));
        return keccak256(abi.encodePacked(_PATH_MAP_SLOT, valueSlot));
    }

    function _getSlotForRouter(address inputToken, address outputToken) internal pure returns (bytes32) {
        bytes32 valueSlot = keccak256(abi.encodePacked(inputToken, outputToken));
        return keccak256(abi.encodePacked(_PATH_TO_ROUTER_MAP_SLOT, valueSlot));
    }
}
