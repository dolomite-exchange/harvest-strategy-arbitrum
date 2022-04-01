pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

import "./interfaces/balancer/IBVault.sol";
import "./interfaces/IUniversalLiquidatorV2.sol";
import "./UniversalLiquidatorV1.sol";


/**
 * @dev This contract can be redeployed many times, as new routers are added into `Constants.sol` since fields are added
 *      via slots. This contract is responsible for liquidating tokens and is intended to be called by the
 *      `RewardForwarder` when `doHardWork` is initiated
 */
contract UniversalLiquidatorV2 is UniversalLiquidatorV1, IUniversalLiquidatorV2 {

    /// @dev    It's way easier to just add a mapping here. This is the only place where we are adding a field variable,
    ///         anyway. Meaning, there won't be any storage collisions
    mapping(bytes32 => bytes) internal _extraDataForSwapMap;

    constructor() public UniversalLiquidatorV1() {
    }

    // ========================= Public Functions =========================

    function finalizeUpgrade() public onlyGovernance {
        super.finalizeUpgrade();

        address[] memory path = new address[](2);
        path[0] = STG;
        path[1] = USDC;
        bytes32 poolId = 0x3a4c6d2404b5eb14915041e01f63200a82f4a343000200000000000000000065;
        _configureSwap(path, BALANCER_VAULT, abi.encode(poolId));
    }

    /**
     * @param _path         The path that is used for selling token at path[0] into path[path.length - 1].
     * @param _router       The router to use for this path.
     * @param _extraData    Any additional data needed to execute the swap for this path and router.
     */
    function configureSwap(
        address[] calldata _path,
        address _router,
        bytes calldata _extraData
    ) external onlyGovernance {
        _configureSwap(_path, _router, _extraData);
    }

    /**
     * @param _paths        The paths that are used for selling token at path[i][0] into path[i][path[i].length - 1].
     * @param _routers      The routers to use for each index, `i`.
     * @param _extraDatas   Any additional data needed to execute the swap for this path and router.
     */
    function configureSwaps(
        address[][] calldata _paths,
        address[] calldata _routers,
        bytes[] calldata _extraDatas
    ) external onlyGovernance {
        for (uint i = 0; i < _paths.length; i++) {
            _configureSwap(_paths[i], _routers[i], _extraDatas[i]);
        }
    }

    function getExtraData(
        address _router,
        address _tokenIn,
        address _tokenOut
    ) public view returns (bytes memory extraData) {
        bytes32 slot = _getSlotForExtraData(_router, _tokenIn, _tokenOut);
        return _extraDataForSwapMap[slot];
    }

    // ========================= Internal Functions =========================

    function _performSwap(
        address _router,
        address _tokenIn,
        address _tokenOut,
        uint _amountIn,
        uint _amountOutMin,
        address _recipient
    ) internal returns (uint amountOut) {
        if (_router == BALANCER_VAULT) {
            bytes memory data = getExtraData(_router, _tokenIn, _tokenOut);
            (bytes32 poolId) = abi.decode(data, (bytes32));
            IBVault.SingleSwap memory singleSwap = IBVault.SingleSwap({
                poolId : poolId,
                kind : IBVault.SwapKind.GIVEN_IN,
                assetIn : IAsset(_tokenIn),
                assetOut : IAsset(_tokenOut),
                amount : _amountIn,
                userData : bytes("")
            });
            IBVault.FundManagement memory fundManagement = IBVault.FundManagement({
                sender : address(this),
                fromInternalBalance : false,
                recipient : address(uint160(_recipient)),
                toInternalBalance : false
            });

            amountOut = IBVault(_router).swap(
                singleSwap,
                fundManagement,
                _amountOutMin,
                block.timestamp
            );
        } else if (_router == UNISWAP_V3_ROUTER) {
            bytes memory data = getExtraData(_router, _tokenIn, _tokenOut);
            uint24 feeTier = 3000;
            if (data.length > 0) {
                (feeTier) = abi.decode(data, (uint24));
            }
            IUniswapV3Router.ExactInputSingleParams memory params = IUniswapV3Router.ExactInputSingleParams({
                tokenIn: _tokenIn,
                tokenOut: _tokenOut,
                fee: feeTier,
                recipient: _recipient,
                deadline: block.timestamp,
                amountIn: _amountIn,
                amountOutMinimum: _amountOutMin,
                sqrtPriceLimitX96: 0
            });
            amountOut = IUniswapV3Router(_router).exactInputSingle(params);
        } else {
            amountOut = super._performSwap(
                _router,
                _tokenIn,
                _tokenOut,
                _amountIn,
                _amountOutMin,
                _recipient
            );
        }
    }

    function _configureSwap(
        address[] memory _path,
        address _router
    ) internal {
        _configureSwap(_path, _router, bytes(""));
    }

    function _configureSwap(
        address[] memory path,
        address router,
        bytes memory extraData
    ) internal {
        require(
            path.length == 2,
            "invalid path length, expected == 2"
        );
        _setBytesData(_getSlotForExtraData(router, path[0], path[path.length - 1]), extraData);
        setAddressArray(_getSlotForPath(path[0], path[path.length - 1]), path);
        setAddress(_getSlotForRouter(path[0], path[path.length - 1]), router);
        emit SwapConfigured(path[0], path[path.length - 1], router, path);
    }

    function _setBytesData(
        bytes32 _slot,
        bytes memory _extraData
    ) internal {
        _extraDataForSwapMap[_slot] = _extraData;
    }

    function _getSlotForExtraData(
        address _router,
        address _inputToken,
        address _outputToken
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(_router, _inputToken, _outputToken));
    }
}
