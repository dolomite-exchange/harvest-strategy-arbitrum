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

library DolomiteMarginActions {

    // ============ Constants ============

    bytes32 constant FILE = "DolomiteMarginActions";

    // ============ Enums ============

    enum ActionType {
        Deposit,   // supply tokens
        Withdraw,  // borrow tokens
        Transfer,  // transfer balance between accounts
        Buy,       // buy an amount of some token (externally)
        Sell,      // sell an amount of some token (externally)
        Trade,     // trade tokens against another account
        Liquidate, // liquidate an undercollateralized or expiring account
        Vaporize,  // use excess tokens to zero-out a completely negative account
        Call       // send arbitrary data to an address
    }

    enum AccountLayout {
        OnePrimary,
        TwoPrimary,
        PrimaryAndSecondary
    }

    enum MarketLayout {
        ZeroMarkets,
        OneMarket,
        TwoMarkets
    }

    // ============ Structs ============

    /*
     * Arguments that are passed to Solo in an ordered list as part of a single operation.
     * Each ActionArgs has an actionType which specifies which action struct that this data will be
     * parsed into before being processed.
     */
    struct ActionArgs {
        ActionType actionType;
        uint256 accountId;
        DolomiteMarginTypes.AssetAmount amount;
        uint256 primaryMarketId;
        uint256 secondaryMarketId;
        address otherAddress;
        uint256 otherAccountId;
        bytes data;
    }

    // ============ Action Types ============

    /*
     * Moves tokens from an address to Solo. Can either repay a borrow or provide additional supply.
     */
    struct DepositArgs {
        DolomiteMarginTypes.AssetAmount amount;
        DolomiteMarginAccount.Info account;
        uint256 market;
        address from;
    }

    /*
     * Moves tokens from Solo to another address. Can either borrow tokens or reduce the amount
     * previously supplied.
     */
    struct WithdrawArgs {
        DolomiteMarginTypes.AssetAmount amount;
        DolomiteMarginAccount.Info account;
        uint256 market;
        address to;
    }

    /*
     * Transfers balance between two accounts. The msg.sender must be an operator for both accounts.
     * The amount field applies to accountOne.
     * This action does not require any token movement since the trade is done internally to Solo.
     */
    struct TransferArgs {
        DolomiteMarginTypes.AssetAmount amount;
        DolomiteMarginAccount.Info accountOne;
        DolomiteMarginAccount.Info accountTwo;
        uint256 market;
    }

    /*
     * Acquires a certain amount of tokens by spending other tokens. Sends takerMarket tokens to the
     * specified exchangeWrapper contract and expects makerMarket tokens in return. The amount field
     * applies to the makerMarket.
     */
    struct BuyArgs {
        DolomiteMarginTypes.AssetAmount amount;
        DolomiteMarginAccount.Info account;
        uint256 makerMarket;
        uint256 takerMarket;
        address exchangeWrapper;
        bytes orderData;
    }

    /*
     * Spends a certain amount of tokens to acquire other tokens. Sends takerMarket tokens to the
     * specified exchangeWrapper and expects makerMarket tokens in return. The amount field applies
     * to the takerMarket.
     */
    struct SellArgs {
        DolomiteMarginTypes.AssetAmount amount;
        DolomiteMarginAccount.Info account;
        uint256 takerMarket;
        uint256 makerMarket;
        address exchangeWrapper;
        bytes orderData;
    }

    /*
     * Trades balances between two accounts using any external contract that implements the
     * AutoTrader interface. The AutoTrader contract must be an operator for the makerAccount (for
     * which it is trading on-behalf-of). The amount field applies to the makerAccount and the
     * inputMarket. This proposed change to the makerAccount is passed to the AutoTrader which will
     * quote a change for the makerAccount in the outputMarket (or will disallow the trade).
     * This action does not require any token movement since the trade is done internally to Solo.
     */
    struct TradeArgs {
        DolomiteMarginTypes.AssetAmount amount;
        DolomiteMarginAccount.Info takerAccount;
        DolomiteMarginAccount.Info makerAccount;
        uint256 inputMarket;
        uint256 outputMarket;
        address autoTrader;
        bytes tradeData;
    }

    /*
     * Each account must maintain a certain margin-ratio (specified globally). If the account falls
     * below this margin-ratio, it can be liquidated by any other account. This allows anyone else
     * (arbitrageurs) to repay any borrowed asset (owedMarket) of the liquidating account in
     * exchange for any collateral asset (heldMarket) of the liquidAccount. The ratio is determined
     * by the price ratio (given by the oracles) plus a spread (specified globally). Liquidating an
     * account also sets a flag on the account that the account is being liquidated. This allows
     * anyone to continue liquidating the account until there are no more borrows being taken by the
     * liquidating account. Liquidators do not have to liquidate the entire account all at once but
     * can liquidate as much as they choose. The liquidating flag allows liquidators to continue
     * liquidating the account even if it becomes collateralized through partial liquidation or
     * price movement.
     */
    struct LiquidateArgs {
        DolomiteMarginTypes.AssetAmount amount;
        DolomiteMarginAccount.Info solidAccount;
        DolomiteMarginAccount.Info liquidAccount;
        uint256 owedMarket;
        uint256 heldMarket;
    }

    /*
     * Similar to liquidate, but vaporAccounts are accounts that have only negative balances
     * remaining. The arbitrageur pays back the negative asset (owedMarket) of the vaporAccount in
     * exchange for a collateral asset (heldMarket) at a favorable spread. However, since the
     * liquidAccount has no collateral assets, the collateral must come from Solo's excess tokens.
     */
    struct VaporizeArgs {
        DolomiteMarginTypes.AssetAmount amount;
        DolomiteMarginAccount.Info solidAccount;
        DolomiteMarginAccount.Info vaporAccount;
        uint256 owedMarket;
        uint256 heldMarket;
    }

    /*
     * Passes arbitrary bytes of data to an external contract that implements the Callee interface.
     * Does not change any asset amounts. This function may be useful for setting certain variables
     * on layer-two contracts for certain accounts without having to make a separate Ethereum
     * transaction for doing so. Also, the second-layer contracts can ensure that the call is coming
     * from an operator of the particular account.
     */
    struct CallArgs {
        DolomiteMarginAccount.Info account;
        address callee;
        bytes data;
    }

    // ============ Helper Functions ============

    function getMarketLayout(
        ActionType actionType
    )
    internal
    pure
    returns (MarketLayout)
    {
        if (
            actionType == ActionType.Deposit
            || actionType == ActionType.Withdraw
            || actionType == ActionType.Transfer
        ) {
            return MarketLayout.OneMarket;
        }
        else if (actionType == ActionType.Call) {
            return MarketLayout.ZeroMarkets;
        }
        return MarketLayout.TwoMarkets;
    }

    function getAccountLayout(
        ActionType actionType
    )
    internal
    pure
    returns (AccountLayout)
    {
        if (
            actionType == ActionType.Transfer
            || actionType == ActionType.Trade
        ) {
            return AccountLayout.TwoPrimary;
        } else if (
            actionType == ActionType.Liquidate
            || actionType == ActionType.Vaporize
        ) {
            return AccountLayout.PrimaryAndSecondary;
        }
        return AccountLayout.OnePrimary;
    }

    // ============ Parsing Functions ============

    function parseDepositArgs(
        DolomiteMarginAccount.Info[] memory accounts,
        ActionArgs memory args
    )
    internal
    pure
    returns (DepositArgs memory)
    {
        assert(args.actionType == ActionType.Deposit);
        return DepositArgs({
        amount: args.amount,
        account: accounts[args.accountId],
        market: args.primaryMarketId,
        from: args.otherAddress
        });
    }

    function parseWithdrawArgs(
        DolomiteMarginAccount.Info[] memory accounts,
        ActionArgs memory args
    )
    internal
    pure
    returns (WithdrawArgs memory)
    {
        assert(args.actionType == ActionType.Withdraw);
        return WithdrawArgs({
        amount: args.amount,
        account: accounts[args.accountId],
        market: args.primaryMarketId,
        to: args.otherAddress
        });
    }

    function parseTransferArgs(
        DolomiteMarginAccount.Info[] memory accounts,
        ActionArgs memory args
    )
    internal
    pure
    returns (TransferArgs memory)
    {
        assert(args.actionType == ActionType.Transfer);
        return TransferArgs({
        amount: args.amount,
        accountOne: accounts[args.accountId],
        accountTwo: accounts[args.otherAccountId],
        market: args.primaryMarketId
        });
    }

    function parseBuyArgs(
        DolomiteMarginAccount.Info[] memory accounts,
        ActionArgs memory args
    )
    internal
    pure
    returns (BuyArgs memory)
    {
        assert(args.actionType == ActionType.Buy);
        return BuyArgs({
        amount: args.amount,
        account: accounts[args.accountId],
        makerMarket: args.primaryMarketId,
        takerMarket: args.secondaryMarketId,
        exchangeWrapper: args.otherAddress,
        orderData: args.data
        });
    }

    function parseSellArgs(
        DolomiteMarginAccount.Info[] memory accounts,
        ActionArgs memory args
    )
    internal
    pure
    returns (SellArgs memory)
    {
        assert(args.actionType == ActionType.Sell);
        return SellArgs({
        amount: args.amount,
        account: accounts[args.accountId],
        takerMarket: args.primaryMarketId,
        makerMarket: args.secondaryMarketId,
        exchangeWrapper: args.otherAddress,
        orderData: args.data
        });
    }

    function parseTradeArgs(
        DolomiteMarginAccount.Info[] memory accounts,
        ActionArgs memory args
    )
    internal
    pure
    returns (TradeArgs memory)
    {
        assert(args.actionType == ActionType.Trade);
        return TradeArgs({
        amount: args.amount,
        takerAccount: accounts[args.accountId],
        makerAccount: accounts[args.otherAccountId],
        inputMarket: args.primaryMarketId,
        outputMarket: args.secondaryMarketId,
        autoTrader: args.otherAddress,
        tradeData: args.data
        });
    }

    function parseLiquidateArgs(
        DolomiteMarginAccount.Info[] memory accounts,
        ActionArgs memory args
    )
    internal
    pure
    returns (LiquidateArgs memory)
    {
        assert(args.actionType == ActionType.Liquidate);
        return LiquidateArgs({
        amount: args.amount,
        solidAccount: accounts[args.accountId],
        liquidAccount: accounts[args.otherAccountId],
        owedMarket: args.primaryMarketId,
        heldMarket: args.secondaryMarketId
        });
    }

    function parseVaporizeArgs(
        DolomiteMarginAccount.Info[] memory accounts,
        ActionArgs memory args
    )
    internal
    pure
    returns (VaporizeArgs memory)
    {
        assert(args.actionType == ActionType.Vaporize);
        return VaporizeArgs({
        amount: args.amount,
        solidAccount: accounts[args.accountId],
        vaporAccount: accounts[args.otherAccountId],
        owedMarket: args.primaryMarketId,
        heldMarket: args.secondaryMarketId
        });
    }

    function parseCallArgs(
        DolomiteMarginAccount.Info[] memory accounts,
        ActionArgs memory args
    )
    internal
    pure
    returns (CallArgs memory)
    {
        assert(args.actionType == ActionType.Call);
        return CallArgs({
        account: accounts[args.accountId],
        callee: args.otherAddress,
        data: args.data
        });
    }
}
