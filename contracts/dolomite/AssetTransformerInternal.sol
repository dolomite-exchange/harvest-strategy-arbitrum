pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "./interfaces/IDolomiteAssetTransformer.sol";
import "./interfaces/IDolomiteExchangeWrapper.sol";
import "./helpers/Require.sol";

contract AssetTransformerInternal is IDolomiteExchangeWrapper {
    using Require for *;

    bytes32 public constant FILE = "AssetTransformerInternal";

    function exchange(
        address tradeOriginator,
        address receiver,
        address makerToken,
        address takerToken,
        uint256 requestedFillAmount,
        bytes calldata orderData
    )
    external
    returns (uint256) {
        (address transformer, address[] memory tokens, uint[] memory amounts) =
        abi.decode(orderData, (address, address[], uint[]));
        return IDolomiteAssetTransformer(transformer).transform(tokens, amounts);
    }

    function getExchangeCost(
        address makerToken,
        address takerToken,
        uint256 desiredMakerToken,
        bytes calldata orderData
    )
    external
    view
    returns (uint256) {
        revert(abi.encodePacked(FILE, "::getExchangeCost: NOT_IMPLEMENTED"));
    }

    function _getTradeData(
        bytes calldata orderData
    ) internal pure returns (address, address[] memory, uint[] memory) {
        return abi.decode(orderData, (address, address[], uint[]));
    }

}