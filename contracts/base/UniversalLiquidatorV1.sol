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
 *      via slots. This contract is responsible for liquidating tokens and is intended to be called by the
 *      `RewardForwarder` when `doHardWork` is initiated
 */
contract UniversalLiquidatorV1 is IUniversalLiquidator, ControllableInit, BaseUpgradeableStrategyStorage, Constants {
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

    function initializeUniversalLiquidator(
        address _storage
    ) public initializer {
        ControllableInit.initialize(_storage);

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

    function scheduleUpgrade(
        address _nextImplementation
    ) external onlyGovernance {
        _setNextImplementation(_nextImplementation);
        emit UpgradeScheduled(_nextImplementation, block.timestamp);
    }

    function finalizeUpgrade() public onlyGovernance {
        _setNextImplementation(address(0));
    }

    function configureSwap(
        address[] calldata _path,
        address _router
    ) external onlyGovernance {
        _configureSwap(_path, _router);
    }

    function configureSwaps(
        address[][] memory _paths,
        address[] memory _routers
    ) public onlyGovernance {
        require(_paths.length == _routers.length, "invalid paths or routers length");
        for (uint i = 0; i < _routers.length; i++) {
            _configureSwap(_paths[i], _routers[i]);
        }
    }

    function getSwapRouter(
        address _inputToken,
        address _outputToken
    ) public view returns (address router) {
        bytes32 slot = _getSlotForRouter(_inputToken, _outputToken);
        // solhint-disable-next-line no-inline-assembly
        assembly {
            router := sload(slot)
        }
    }

    function swapTokens(
        address _tokenIn,
        address _tokenOut,
        uint256 _amountIn,
        uint256 _amountOutMin,
        address _recipient
    ) external returns (uint) {
        require(
            msg.sender == IController(controller()).rewardForwarder(),
            "only callable from fee reward forwarder"
        );

        IERC20(_tokenIn).safeTransferFrom(msg.sender, address(this), _amountIn);

        if (_tokenIn == _tokenOut) {
            // if the input and output tokens are the same, return amountIn
            uint amountOut = _amountIn;
            IERC20(_tokenIn).safeTransfer(_recipient, amountOut);
            return amountOut;
        }

        address[] memory path = new address[](_tokenOut != WETH ? 3 : 2);
        path[0] = _tokenIn;
        if (_tokenOut != WETH) {
            path[1] = WETH;
        }
        path[path.length - 1] = _tokenOut;

        for (uint i = 0; i < path.length - 1; i++) {
            address router = getAddress(_getSlotForRouter(path[i], path[i + 1]));
            require(
                router != address(0),
                "invalid router for path"
            );
            if (IERC20(path[i]).allowance(address(this), router) < _amountIn) {
                IERC20(path[i]).safeApprove(router, 0);
                IERC20(path[i]).safeApprove(router, _amountIn);
            }

            _amountIn = _performSwap(
                router,
                path[i],
                path[i + 1],
                _amountIn,
                i == path.length - 2 ? _amountOutMin : 1,
                i == path.length - 2 ? _recipient : address(this)
            );
        }

        // we re-assigned amountIn to be eq to amountOut, so this require statement makes sense
        require(
            _amountIn >= _amountOutMin,
            "insufficient amount out"
        );

        return _amountIn;
    }

    function _address2ToMemory(
        address[2] memory _tokens
    ) internal pure returns (address[] memory) {
        address[] memory dynamicTokens = new address[](_tokens.length);
        for (uint i = 0; i < _tokens.length; i++) {
            dynamicTokens[i] = _tokens[i];
        }
        return dynamicTokens;
    }

    function _performSwap(
        address _router,
        address _tokenIn,
        address _tokenOut,
        uint _amountIn,
        uint _amountOutMin,
        address _recipient
    ) internal returns (uint amountOut) {
        // TODO add Dolomite router
        if (_router == SUSHI_ROUTER) {
            address[] memory path = new address[](2);
            path[0] = _tokenIn;
            path[1] = _tokenOut;

            amountOut = IUniswapV2Router02(_router).swapExactTokensForTokens(
                _amountIn,
                _amountOutMin,
                path,
                _recipient,
                block.timestamp
            )[path.length - 1];
        } else if (_router == UNISWAP_V3_ROUTER) {
            IUniswapV3Router.ExactInputSingleParams memory params = IUniswapV3Router.ExactInputSingleParams({
                tokenIn: _tokenIn,
                tokenOut: _tokenOut,
                fee: 3000,
                recipient: _recipient,
                deadline: block.timestamp,
                amountIn: _amountIn,
                amountOutMinimum: _amountOutMin,
                sqrtPriceLimitX96: 0
            });
            amountOut = IUniswapV3Router(_router).exactInputSingle(params);
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

    function _getSlotForPath(address _inputToken, address _outputToken) internal pure returns (bytes32) {
        bytes32 valueSlot = keccak256(abi.encodePacked(_inputToken, _outputToken));
        return keccak256(abi.encodePacked(_PATH_MAP_SLOT, valueSlot));
    }

    function _getSlotForRouter(address _inputToken, address _outputToken) internal pure returns (bytes32) {
        bytes32 valueSlot = keccak256(abi.encodePacked(_inputToken, _outputToken));
        return keccak256(abi.encodePacked(_PATH_TO_ROUTER_MAP_SLOT, valueSlot));
    }
}
