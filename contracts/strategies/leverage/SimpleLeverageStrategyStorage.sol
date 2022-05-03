pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

import "../../base/upgradability/BaseUpgradeableStrategy.sol";
import "../../base/dolomite/interfaces/IDolomiteMargin.sol";
import "../../base/dolomite/lib/DolomiteMarginDecimal.sol";


contract SimpleLeverageStrategyStorage is BaseUpgradeableStrategy {
    using DolomiteMarginDecimal for *;
    using SafeMath for uint256;


    // ========================= Events =========================

    event FTokensSet(address[] _fTokens);
    event BorrowTokensSet(address[] _borrowTokens);
    event FTokenWeightsSet(uint256[] _fTokenInitialWeights);

    // ========================= Constants =========================

    bytes32 internal constant _F_TOKENS_SLOT = 0xf188e1de350c9cd45070f03b52e0f555e5287f7263268512a04a270b40adc94e;
    bytes32 internal constant _BORROW_TOKENS_SLOT = 0x953adea603236911acee8484929f7f653eda9d977d12e523b651f8908408a95c;
    bytes32 internal constant _F_TOKEN_INITIAL_WEIGHTS_SLOT = 0x1d534d8ecfcf0eea44e9c2b166581c35ca56bbb8a4f1b76c15bf52876ce5895e;
    bytes32 internal constant _TARGET_COLLATERALIZATION_SLOT = 0x21bd4ad06109fb88c15d4cd366f71d076d5e3e7be67c65e57e481fb37b635336;
    bytes32 internal constant _COLLATERALIZATION_FLEX_PERCENTAGE_SLOT = 0xaa80531865fdaebb3741b8a97a2bec9f8a17de868f5dac601249b28bab693f16;

    uint256 public constant TOTAL_WEIGHT = 1e18;

    // ========================= Public Functions =========================

    constructor() public {
        assert(_F_TOKENS_SLOT == bytes32(uint256(keccak256("eip1967.vaultStorage.fTokens")) - 1));
        assert(_BORROW_TOKENS_SLOT == bytes32(uint256(keccak256("eip1967.vaultStorage.borrowTokens")) - 1));
        assert(_F_TOKEN_INITIAL_WEIGHTS_SLOT == bytes32(uint256(keccak256("eip1967.vaultStorage.fTokenInitialWeights")) - 1));
        assert(_TARGET_COLLATERALIZATION_SLOT == bytes32(uint256(keccak256("eip1967.vaultStorage.targetCollateralization")) - 1));
        assert(_COLLATERALIZATION_FLEX_PERCENTAGE_SLOT == bytes32(uint256(keccak256("eip1967.vaultStorage.collateralizationFlexPercentage")) - 1));
    }

    function fTokens() public view returns (address[] memory) {
        return getAddressArray(_F_TOKENS_SLOT);
    }

    function borrowTokens() public view returns (address[] memory) {
        return getAddressArray(_BORROW_TOKENS_SLOT);
    }

    function fTokenInitialWeights() public view returns (uint[] memory) {
        return getUint256Array(_F_TOKEN_INITIAL_WEIGHTS_SLOT);
    }

    /**
     * @return  The target collateralization that this vault aims for, before a rebalance may occur. Has 18 decimals.
     *          Meaning, 2000000000000000000 == 200% == 2.0
     */
    function targetCollateralization() public view returns (DolomiteMarginDecimal.D256 memory) {
        return DolomiteMarginDecimal.D256({
            value: getUint256(_TARGET_COLLATERALIZATION_SLOT)
        });
    }

    /**
     * @return  The flex collateralization that this vault aims for, which allows the `targetCollateralization` to hover
     *          around these levels before a rebalance occurs. A value of 50000000000000000 == 5% == 0.05. This would
     *          mean the `targetCollateralization` can hover between 190% and 210% before a rebalance occurs, assuming
     *          the `targetCollateralization` is 200%.
     */
    function collateralizationFlexPercentage() public view returns (DolomiteMarginDecimal.D256 memory) {
        return DolomiteMarginDecimal.D256({
            value: getUint256(_COLLATERALIZATION_FLEX_PERCENTAGE_SLOT)
        });
    }

    function upperTargetCollateralization() public view returns (DolomiteMarginDecimal.D256 memory) {
        return DolomiteMarginDecimal.D256({
            value: targetCollateralization().value.mul(collateralizationFlexPercentage().onePlus())
        });
    }

    function lowerTargetCollateralization() public view returns (DolomiteMarginDecimal.D256 memory) {
        return DolomiteMarginDecimal.D256({
            value: targetCollateralization().value.div(collateralizationFlexPercentage().onePlus())
        });
    }

    function cachedPricePerShare(address _fToken) public view returns (uint256) {
        return getUint256(keccak256(abi.encodePacked("cachedSharePrice", _fToken)));
    }

    function cachedBorrowWei(address _borrowToken) public view returns (uint256) {
        return getUint256(keccak256(abi.encodePacked("cachedBorrowWei", _borrowToken)));
    }

    /**
     * @return  The user's collateralization, using 18 decimals of precision. This is calculated by dividing the supply
     *          value by the account's borrow value
     */
    function getCollateralization() public view returns (DolomiteMarginDecimal.D256 memory) {
        (
            DolomiteMarginMonetary.Value memory supplyValue,
            DolomiteMarginMonetary.Value memory borrowValue
        ) = IDolomiteMargin(rewardPool()).getAccountValues(_defaultMarginAccount());

        if (borrowValue.value == 0) {
            return DolomiteMarginDecimal.D256({
                value: uint(-1)
            });
        }

        return DolomiteMarginDecimal.D256({
            value: supplyValue.value.mul(1e18).div(borrowValue.value)
        });
    }

    // ========================= Internal Functions =========================

    function _defaultMarginAccount() internal view returns (DolomiteMarginAccount.Info memory) {
        return DolomiteMarginAccount.Info({
            owner: address(this),
            number: 0
        });
    }

    /**
     * @param _amountWei        The amount being traded from `_takerToken` to `_makerToken` by DolomiteMargin.
     * @param _takerMarketId    The token being withdrawn from DolomiteMargin to be converted. When increasing leverage,
     *                          this will be the `borrowToken`. When decreasing leverage, this will be the `fToken`.
     * @param _makerMarketId    The token being deposited into DolomiteMargin, after the conversion is done. When
     *                          increasing leverage, this will be the `fToken`. When decreasing leverage, this will be
     *                          the `borrowToken`.
     * @param _tokenIndex       The index of `_takerToken` and `_makerToken` in their respective arrays.
     */
    function _encodeSell(
        uint256 _amountWei,
        uint256 _takerMarketId,
        uint256 _makerMarketId,
        uint256 _tokenIndex
    ) internal view returns (DolomiteMarginActions.ActionArgs memory) {
        return DolomiteMarginActions.ActionArgs({
            actionType: DolomiteMarginActions.ActionType.Sell,
            accountId: 0,
            amount: DolomiteMarginTypes.AssetAmount({
                sign: false,
                denomination: DolomiteMarginTypes.AssetDenomination.Wei,
                ref: DolomiteMarginTypes.AssetReference.Delta,
                value: _amountWei
            }),
            primaryMarketId: _takerMarketId,
            secondaryMarketId: _makerMarketId,
            otherAddress: address(this),
            otherAccountId: 0,
            data: abi.encode(_tokenIndex)
        });
    }

    /**
     * @param _amountWei        The amount being traded from `_makerToken` to `_takerToken` by DolomiteMargin.
     * @param _takerMarketId    The token being withdrawn from DolomiteMargin to be converted. When increasing leverage,
     *                          this will be the `borrowToken`. When decreasing leverage, this will be the `fToken`.
     * @param _makerMarketId    The token being deposited into DolomiteMargin, after the conversion is done. When
     *                          increasing leverage, this will be the `fToken`. When decreasing leverage, this will be
     *                          the `borrowToken`.
     * @param _tokenIndex       The index of `_takerToken` and `_makerToken` in their respective arrays.
     */
    function _encodeBuy(
        uint256 _amountWei,
        uint256 _takerMarketId,
        uint256 _makerMarketId,
        uint256 _tokenIndex
    ) internal view returns (DolomiteMarginActions.ActionArgs memory) {
        return DolomiteMarginActions.ActionArgs({
            actionType: DolomiteMarginActions.ActionType.Buy,
            accountId: 0,
            amount: DolomiteMarginTypes.AssetAmount({
                sign: true,
                denomination: DolomiteMarginTypes.AssetDenomination.Wei,
                ref: DolomiteMarginTypes.AssetReference.Delta,
                value: _amountWei
            }),
            primaryMarketId: _makerMarketId,
            secondaryMarketId: _takerMarketId,
            otherAddress: address(this),
            otherAccountId: 0,
            data: abi.encode(_tokenIndex)
        });
    }

    function _encodeDeposit(
        uint256 _amountWei,
        uint256 _marketId
    ) internal view returns (DolomiteMarginActions.ActionArgs memory) {
        return DolomiteMarginActions.ActionArgs({
            actionType: DolomiteMarginActions.ActionType.Deposit,
            accountId: 0,
            amount: DolomiteMarginTypes.AssetAmount({
                sign: true,
                denomination: DolomiteMarginTypes.AssetDenomination.Wei,
                ref: DolomiteMarginTypes.AssetReference.Delta,
                value: _amountWei
            }),
            primaryMarketId: _marketId,
            secondaryMarketId: 0,
            otherAddress: address(this),
            otherAccountId: 0,
            data: bytes("")
        });
    }

    function _encodeWithdraw(
        uint256 _amountWei,
        uint256 _marketId
    ) internal view returns (DolomiteMarginActions.ActionArgs memory) {
        return DolomiteMarginActions.ActionArgs({
            actionType: DolomiteMarginActions.ActionType.Withdraw,
            accountId: 0,
            amount: DolomiteMarginTypes.AssetAmount({
                sign: false,
                denomination: DolomiteMarginTypes.AssetDenomination.Wei,
                ref: _amountWei == uint(-1)
                    ? DolomiteMarginTypes.AssetReference.Target
                    : DolomiteMarginTypes.AssetReference.Delta,
                value: _amountWei == uint(-1) ? 0 : _amountWei
            }),
            primaryMarketId: _marketId,
            secondaryMarketId: 0,
            otherAddress: address(this),
            otherAccountId: 0,
            data: bytes("")
        });
    }

    function _setTokens(
        address[] memory _fTokens,
        address[] memory _borrowTokens,
        uint256[] memory _fTokenInitialWeights
    ) internal {
        require(
            _fTokens.length == _borrowTokens.length && _fTokenInitialWeights.length == _fTokens.length,
            "token lengths must equal"
        );
        uint totalWeight = 0;
        for (uint i = 0; i < _fTokenInitialWeights.length; i++) {
            totalWeight = totalWeight.add(_fTokenInitialWeights[i]);
        }
        require(
            totalWeight == TOTAL_WEIGHT,
            "_fTokenInitialWeights must sum to 1e18"
        );

        address[] memory oldFTokens = fTokens();
        address[] memory oldBorrowTokens = borrowTokens();
        _repayLoanAndWithdrawCollateral(oldFTokens, oldBorrowTokens);

        _setAllowanceForAll(oldFTokens, 0); // unset old allowances
        _setAllowanceForAll(_fTokens, uint(-1)); // set new allowances
        setAddressArray(_F_TOKENS_SLOT, _fTokens);
        emit FTokensSet(_fTokens);

        _setAllowanceForAll(oldBorrowTokens, 0); // unset old allowances
        _setAllowanceForAll(_borrowTokens, uint(-1)); // set new allowances
        setAddressArray(_BORROW_TOKENS_SLOT, _borrowTokens);
        emit BorrowTokensSet(_borrowTokens);

        setUint256Array(_F_TOKEN_INITIAL_WEIGHTS_SLOT, _fTokenInitialWeights);
        emit FTokenWeightsSet(_fTokenInitialWeights);
    }

    function _setTargetCollateralization(DolomiteMarginDecimal.D256 memory _targetCollateralization) internal {
        setUint256(_TARGET_COLLATERALIZATION_SLOT, _targetCollateralization.value);
    }

    function _setCollateralizationFlexPercentage(
        DolomiteMarginDecimal.D256 memory _collateralizationFlexPercentage
    ) internal {
        setUint256(_COLLATERALIZATION_FLEX_PERCENTAGE_SLOT, _collateralizationFlexPercentage.value);
    }

    function _setCachedSharePrice(
        address _fToken,
        uint256 _cachedSharePrice
    ) internal {
        setUint256(keccak256(abi.encodePacked("cachedSharePrice", _fToken)), _cachedSharePrice);
    }

    function _setCachedSupplyWei(
        address _borrowToken,
        uint256 _cachedSupplyWei
    ) internal {
        setUint256(keccak256(abi.encodePacked("cachedSupplyWei", _borrowToken)), _cachedSupplyWei);
    }

    function _setCachedBorrowWei(
        address _borrowToken,
        uint256 _cachedBorrowWei
    ) internal {
        setUint256(keccak256(abi.encodePacked("cachedBorrowWei", _borrowToken)), _cachedBorrowWei);
    }

    function _setCachedLoanState() internal {
        IDolomiteMargin _dolomiteMargin = IDolomiteMargin(rewardPool());
        DolomiteMarginAccount.Info memory account = _defaultMarginAccount();

        address[] memory _fTokens = fTokens();
        address[] memory _borrowTokens = borrowTokens();
        for (uint i = 0; i < _fTokens.length; i++) {
            uint supplyMarketId = _dolomiteMargin.getMarketIdByTokenAddress(_fTokens[i]);
            DolomiteMarginTypes.Wei memory supplyWei = _dolomiteMargin.getAccountWei(account, supplyMarketId);
            Require.that(
                supplyWei.sign || supplyWei.value == 0,
                FILE,
                "invalid supply state"
            );
            _setCachedSupplyWei(
                _fTokens[i],
                supplyWei.value
            );

            uint borrowMarketId = _dolomiteMargin.getMarketIdByTokenAddress(_borrowTokens[i]);
            DolomiteMarginTypes.Wei memory borrowWei = _dolomiteMargin.getAccountWei(account, borrowMarketId);
            Require.that(
                !borrowWei.sign || borrowWei.value == 0,
                FILE,
                "invalid borrow state"
            );
            _setCachedBorrowWei(
                _borrowTokens[i],
                borrowWei.value
            );
        }
    }

    // ========================= Abstract Functions =========================

    function _repayLoanAndWithdrawCollateral(
        address[] memory _fTokens,
        address[] memory _borrowTokens
    ) internal;

    function _setAllowanceForAll(
        address[] memory _tokens,
        uint _allowance
    ) internal;
}
