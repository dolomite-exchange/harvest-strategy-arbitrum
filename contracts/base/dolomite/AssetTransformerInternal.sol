pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

import "./interfaces/IAssetTransformerInternal.sol";
import "./interfaces/IDolomiteCallee.sol";
import "./interfaces/IDolomiteAssetTransformer.sol";
import "./interfaces/IDolomiteMargin.sol";

import "./lib/OnlyDolomiteMargin.sol";
import "./lib/Require.sol";

contract AssetTransformerInternal is IDolomiteCallee, OnlyDolomiteMargin, IAssetTransformerInternal {
    using Require for *;
    using SafeERC20 for IERC20;

    bytes32 public constant FILE = "AssetTransformerInternal";

    address public dolomiteYieldFarmingRouter;

    constructor(
        address _dolomiteMargin
    ) public OnlyDolomiteMargin(_dolomiteMargin) {
    }

    function setDolomiteYieldFarmingRouter(address _dolomiteYieldFarmingRouter) external {
        Require.that(
            dolomiteYieldFarmingRouter == address(0),
            FILE,
            "router already set"
        );

        dolomiteYieldFarmingRouter = _dolomiteYieldFarmingRouter;
    }

    function callFunction(
        address sender,
        DolomiteMarginAccount.Info memory,
        bytes memory data
    )
    public
    onlyDolomiteMargin {
        Require.that(
            sender != address(0) && sender == dolomiteYieldFarmingRouter,
            FILE,
            "sender must be global operator",
            sender
        );

        TransformationType transformationType;
        (transformationType, data) = abi.decode(data, (TransformationType, bytes));

        if (transformationType == TransformationType.TRANSFORM) {
            _performTransform(sender, data);
        } else {
            assert(transformationType == TransformationType.REVERT);
            _performRevert(sender, data);
        }
    }

    function _performTransform(address sender, bytes memory data) internal {
        (
            address transformer,
            address fToken,
            address[] memory inputTokens,
            uint[] memory inputAmounts,
            address dustRecipient,
            bytes memory extraData
        ) = abi.decode(data, (address, address, address[], uint[], address, bytes));

        // pull the deposit tokens into here and set the appropriate allowance on the transformer
        for (uint i = 0; i < inputTokens.length; i++) {
            uint balance = IERC20(inputTokens[i]).balanceOf(address(this));
            if (inputAmounts[i] > balance) {
                // Any tokens that have a balance < the inputAmount needs to have the remainder pulled
                // can use unsafe subtraction because the if-statement only fires if no underflow occurs
                IERC20(inputTokens[i]).safeTransferFrom(sender, address(this), inputAmounts[i] - balance);
            }

            IERC20(inputTokens[i]).safeApprove(transformer, 0);
            IERC20(inputTokens[i]).safeApprove(transformer, inputAmounts[i]);
        }

        uint fAmount = IDolomiteAssetTransformer(transformer).transform(
            inputTokens,
            inputAmounts,
            dustRecipient,
            extraData
        );

        // transfer the resulting fAmount to `sender` so it can be deposited into DolomiteMargin
        IERC20(fToken).safeTransferFrom(transformer, sender, fAmount);
    }

    function _performRevert(address sender, bytes memory data) internal {
        (
            address transformer,
            address fToken,
            uint fAmountWei,
            address[] memory outputTokens,
            bytes memory extraData
        ) = abi.decode(data, (address, address, uint, address[], bytes));

        IERC20(fToken).safeApprove(transformer, 0);
        IERC20(fToken).safeApprove(transformer, fAmountWei);

        uint[] memory outputAmounts = IDolomiteAssetTransformer(transformer).transformBack(
            fAmountWei,
            outputTokens,
            extraData
        );

        // transfer the resulting outputAmounts to `sender` so they can be deposited into DolomiteMargin
        for (uint i = 0; i < outputTokens.length; i++) {
            IERC20(outputTokens[i]).safeTransferFrom(transformer, sender, outputAmounts[i]);
        }
    }
}
