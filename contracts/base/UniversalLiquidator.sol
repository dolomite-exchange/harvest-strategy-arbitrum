pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/upgrades/contracts/Initializable.sol";
import "./inheritance/Constants.sol";
import "./inheritance/ControllableInit.sol";
import "./interfaces/IController.sol";
import "./interfaces/IUpgradeSource.sol";
import "./interfaces/IUniversalLiquidator.sol";
import "./interfaces/uniswap/IUniswapV2Router02.sol";
import "./interfaces/uniswap/IUniswapV3Router.sol";
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

        // FARM output token
        _configureSwap(_address2ToMemory([WETH, FARM]), SUSHI_ROUTER);

        // WETH output token
        _configureSwap(_address2ToMemory([CRV, WETH]), UNISWAP_V3_ROUTER);
        _configureSwap(_address2ToMemory([DAI, WETH]), UNISWAP_V3_ROUTER);
        _configureSwap(_address2ToMemory([SUSHI, WETH]), SUSHI_ROUTER);
        _configureSwap(_address2ToMemory([USDC, WETH]), UNISWAP_V3_ROUTER);
        _configureSwap(_address2ToMemory([USDT, WETH]), UNISWAP_V3_ROUTER);
        _configureSwap(_address2ToMemory([WBTC, WETH]), UNISWAP_V3_ROUTER);

        // USDC output token
        _configureSwap(_address2ToMemory([WETH, USDC]), UNISWAP_V3_ROUTER);
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

        IERC20(tokenIn).safeTransferFrom(msg.sender, address(this), amountIn);

        if (tokenIn == tokenOut) {
            // if the input and output tokens are the same, return amountIn
            uint amountOut = amountIn;
            IERC20(tokenIn).safeTransfer(recipient, amountOut);
            return amountOut;
        }

        address[] memory path = new address[](tokenOut != WETH ? 3 : 2);
        path[0] = tokenIn;
        if (tokenOut != WETH) {
            path[1] = WETH;
        }
        path[path.length - 1] = tokenOut;

        for (uint i = 0; i < path.length - 1; i++) {
            address router = getAddress(_getSlotForRouter(path[i], path[i + 1]));
            require(
                router != address(0),
                "invalid router for path"
            );
            if (IERC20(path[i]).allowance(address(this), router) < amountIn) {
                IERC20(path[i]).safeApprove(router, 0);
                IERC20(path[i]).safeApprove(router, amountIn);
            }

            amountIn = _performSwap(
                router,
                path[i],
                path[i + 1],
                amountIn,
                1,
                recipient
            );
        }

        // we re-assign amountIn to be eq to amountOut
        require(
            amountIn >= amountOutMin,
            "insufficient amount out"
        );

        return amountIn;
    }

    function _address2ToMemory(address[2] memory tokens) internal pure returns (address[] memory) {
        address[] memory dynamicTokens = new address[](tokens.length);
        for (uint i = 0; i < tokens.length; i++) {
            dynamicTokens[i] = tokens[i];
        }
        return dynamicTokens;
    }

    function _performSwap(
        address router,
        address tokenIn,
        address tokenOut,
        uint amountIn,
        uint amountOutMin,
        address recipient
    ) internal returns (uint amountOut) {
        // TODO add Dolomite router
        if (router == SUSHI_ROUTER) {
            address[] memory path = new address[](2);
            path[0] = tokenIn;
            path[1] = tokenOut;

            amountOut = IUniswapV2Router02(router).swapExactTokensForTokens(
                amountIn,
                amountOutMin,
                path,
                recipient,
                block.timestamp
            )[path.length - 1];
        } else if (router == UNISWAP_V3_ROUTER) {
            IUniswapV3Router.ExactInputSingleParams memory params = IUniswapV3Router.ExactInputSingleParams({
                tokenIn: tokenIn,
                tokenOut: tokenOut,
                fee: 3000,
                recipient: address(this),
                deadline: block.timestamp,
                amountIn: amountIn,
                amountOutMinimum: amountOutMin,
                sqrtPriceLimitX96: 0
            });
            amountOut = IUniswapV3Router(router).exactInputSingle(params);
        } else {
            revert("unknown router");
        }
    }

    function _configureSwap(
        address[] memory path,
        address router
    ) internal {
        require(
            path.length == 2,
            "invalid path length, expected == 2"
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
