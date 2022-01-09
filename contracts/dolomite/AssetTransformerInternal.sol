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

contract AssetTransformerInternal is IDolomiteExchangeWrapper, OnlyDolomiteMargin {
    using Require for *;
    using SafeERC20 for IERC20;

    bytes32 public constant FILE = "AssetTransformerInternal";

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
    returns (uint256 fAmount) {
        // already checked that msg.sender is DolomiteMargin; now check msg.sender equals receiver
        Require.that(
            msg.sender == receiver,
            FILE,
            "invalid receiver",
            receiver
        );

        (address transformer, address[] memory tokens, uint[] memory amounts, address dustRecipient) =
        abi.decode(orderData, (address, address[], uint[], address));

        Require.that(
            IDolomiteAssetTransformer(transformer).fToken() == makerToken,
            FILE,
            "invalid makerToken",
            makerToken
        );

        fAmount = IDolomiteAssetTransformer(transformer).transform(tokens, amounts, dustRecipient);
        IERC20(makerToken).safeTransferFrom(transformer, address(this), fAmount);

        IERC20(makerToken).safeApprove(receiver, fAmount);
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
