/*

    Copyright 2021 Dolomite.

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.

*/

pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

import "./DolomiteMarginTypes.sol";
import "./DolomiteMarginAccount.sol";
import "./DolomiteMarginActions.sol";

library DolomiteMarginActionsHelper {

    function createDeposit(
        uint _accountIndex,
        uint _marketId,
        address _fromAddress,
        uint _amountWei
    ) internal pure returns (DolomiteMarginActions.ActionArgs memory) {
        DolomiteMarginTypes.AssetAmount memory assetAmount = DolomiteMarginTypes.AssetAmount({
            sign: true,
            denomination: DolomiteMarginTypes.AssetDenomination.Wei,
            ref: DolomiteMarginTypes.AssetReference.Delta,
            value: _amountWei
        });

        return DolomiteMarginActions.ActionArgs({
            actionType: DolomiteMarginActions.ActionType.Deposit,
            accountId: _accountIndex,
            amount: assetAmount,
            primaryMarketId: _marketId,
            secondaryMarketId: 0,
            otherAddress: _fromAddress,
            otherAccountId: 0,
            data: bytes("")
        });
    }

    function createWithdrawal(
        uint _accountIndex,
        uint _marketId,
        address _toAddress,
        uint _amountWei
    ) internal pure returns (DolomiteMarginActions.ActionArgs memory) {
        DolomiteMarginTypes.AssetAmount memory assetAmount;
        if (_amountWei == uint(-1)) {
            assetAmount = DolomiteMarginTypes.AssetAmount({
                sign: true,
                denomination: DolomiteMarginTypes.AssetDenomination.Wei,
                ref: DolomiteMarginTypes.AssetReference.Target,
                value: 0
            });
        } else {
            assetAmount = DolomiteMarginTypes.AssetAmount({
                sign: true,
                denomination: DolomiteMarginTypes.AssetDenomination.Wei,
                ref: DolomiteMarginTypes.AssetReference.Delta,
                value: _amountWei
            });
        }

        return createWithdrawalWithAssetAmount(
            _accountIndex,
            _marketId,
            _toAddress,
            assetAmount
        );
    }

    function createWithdrawalWithAssetAmount(
        uint _accountIndex,
        uint _marketId,
        address _toAddress,
        DolomiteMarginTypes.AssetAmount memory _assetAmount
    ) internal pure returns (DolomiteMarginActions.ActionArgs memory) {
        return DolomiteMarginActions.ActionArgs({
            actionType: DolomiteMarginActions.ActionType.Withdraw,
            accountId: _accountIndex,
            amount: _assetAmount,
            primaryMarketId: _marketId,
            secondaryMarketId: 0,
            otherAddress: _toAddress,
            otherAccountId: 0,
            data: bytes("")
        });
    }

    /**
     * @param _fromAccountIndex The index of the `from` account in the `accounts` array
     * @param _toAccountIndex   The index of the `to` account in the `accounts` array
     * @param _marketId         The marketID being transferred
     * @param _amountWei        The wei amount being transferred or MAX_UINT (uint(-1)) for all
     */
    function createTransfer(
        uint _fromAccountIndex,
        uint _toAccountIndex,
        uint _marketId,
        uint _amountWei
    ) internal pure returns (DolomiteMarginActions.ActionArgs memory) {
        DolomiteMarginTypes.AssetAmount memory assetAmount;
        if (_amountWei == uint(- 1)) {
            assetAmount = DolomiteMarginTypes.AssetAmount({
                sign: true,
                denomination: DolomiteMarginTypes.AssetDenomination.Wei,
                ref: DolomiteMarginTypes.AssetReference.Target,
                value: 0
            });
        } else {
            assetAmount = DolomiteMarginTypes.AssetAmount({
                sign: false,
                denomination: DolomiteMarginTypes.AssetDenomination.Wei,
                ref: DolomiteMarginTypes.AssetReference.Delta,
                value: _amountWei
            });
        }

        return createTransferWithAssetAmount(
            _fromAccountIndex,
            _toAccountIndex,
            _marketId,
            assetAmount
        );
    }

    /**
     * @param _fromAccountIndex The index of the `from` account in the `accounts` array
     * @param _toAccountIndex   The index of the `to` account in the `accounts` array
     * @param _marketId         The marketID being transferred
     * @param _assetAmount      The asset amount being transferred
     */
    function createTransferWithAssetAmount(
        uint _fromAccountIndex,
        uint _toAccountIndex,
        uint _marketId,
        DolomiteMarginTypes.AssetAmount memory _assetAmount
    ) internal pure returns (DolomiteMarginActions.ActionArgs memory) {
        return DolomiteMarginActions.ActionArgs({
            actionType: DolomiteMarginActions.ActionType.Transfer,
            accountId: _fromAccountIndex,
            amount: _assetAmount,
            primaryMarketId: _marketId,
            secondaryMarketId: 0,
            otherAddress: address(0),
            otherAccountId: _toAccountIndex,
            data: bytes("")
        });
    }

    function createCall(
        uint _accountIndex,
        address _calleeAddress,
        bytes memory _data
    ) internal pure returns (DolomiteMarginActions.ActionArgs memory) {
        DolomiteMarginTypes.AssetAmount memory assetAmount = DolomiteMarginTypes.AssetAmount({
            sign: false,
            denomination: DolomiteMarginTypes.AssetDenomination.Wei,
            ref: DolomiteMarginTypes.AssetReference.Delta,
            value: 0
        });

        return DolomiteMarginActions.ActionArgs({
            actionType: DolomiteMarginActions.ActionType.Call,
            accountId: _accountIndex,
            amount: assetAmount,
            primaryMarketId: 0,
            secondaryMarketId: 0,
            otherAddress: _calleeAddress,
            otherAccountId: 0,
            data: _data
        });
    }
}
