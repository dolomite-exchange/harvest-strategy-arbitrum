pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "./interfaces/IDolomiteAssetTransformer.sol";
import "./interfaces/IDolomiteExchangeWrapper.sol";

import "./lib/OnlyDolomiteMargin.sol";
import "./lib/Require.sol";

contract AssetReverterInternal is IDolomiteExchangeWrapper, OnlyDolomiteMargin {
    using Require for *;
    using SafeERC20 for IERC20;

    bytes32 public constant FILE = "AssetReverterInternal";

    constructor(
        address _dolomiteMargin
    ) public OnlyDolomiteMargin(_dolomiteMargin) {
    }

    function exchange(
        address tradeOriginator,
        address receiver,
        address makerToken,
        address takerToken,
        uint256 requestedFillAmount,
        bytes calldata orderData
    )
    external
    onlyDolomiteMargin
    returns (uint256) {
        Require.that(
            msg.sender == receiver,
            FILE,
            "invalid receiver",
            receiver
        );

        (address transformer, uint fAmount, address[] memory outputTokens) =
        abi.decode(orderData, (address, uint, address[]));

        Require.that(
            fAmount == requestedFillAmount,
            FILE,
            "invalid requestedFillAmount",
            requestedFillAmount
        );

        (address[] memory tokens, uint[] memory amounts) = IDolomiteAssetTransformer(transformer).transformBack(fAmount, outputTokens);
        for (uint i = 0; i < tokens.length; i++) {
            if (amounts[i] > 0) {
                IERC20(tokens[i]).safeTransferFrom(transformer, address(this), amounts[i]);
                IERC20(tokens[i]).safeApprove(msg.sender, amounts[i]);
            }
        }

        return 0;
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
        revert(string(abi.encodePacked(FILE, "::getExchangeCost: NOT_IMPLEMENTED")));
    }
}
