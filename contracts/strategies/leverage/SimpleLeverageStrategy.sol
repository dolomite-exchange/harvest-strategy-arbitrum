pragma solidity ^0.5.16;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/math/Math.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";

import "../../base/dolomite/interfaces/IDolomiteMargin.sol";
import "../../base/dolomite/lib/DolomiteMarginDecimal.sol";

import "../../base/interfaces/IStrategy.sol";
import "../../base/interfaces/IERC4626.sol";
import "../../base/upgradability/BaseUpgradeableStrategy.sol";
import "../../base/dolomite/interfaces/IDolomiteExchangeWrapper.sol";


/**
 * @dev Utilizes borrowed assets to perform a delta-neutral strategy, where the delta between the supply rate of
 *      supplied assets and the borrow rate of borrowed assets is arbitraged for amplified yield.
 */
contract SimpleLeverageStrategy is IStrategy, BaseUpgradeableStrategy, IDolomiteExchangeWrapper {
    using DolomiteMarginDecimal for *;
    using SafeMath for uint256;

    // ========================= Events =========================

    event FTokensSet(address[] _fTokens);
    event BorrowTokensSet(address[] _borrowTokens);
    event FTokenWeightsSet(uint256[] _fTokenInitialWeights);
    event RebalanceAssets();
    event RebalanceDenied();

    // ========================= Constants =========================

    bytes32 internal constant _DOLOMITE_MARGIN_SLOT = 0xac94db1926f56f9678439d736e0bce5e9cf96e68296b79021f6969ff6e0f2eb2;
    bytes32 internal constant _F_TOKENS_SLOT = 0xf188e1de350c9cd45070f03b52e0f555e5287f7263268512a04a270b40adc94e;
    bytes32 internal constant _BORROW_TOKENS_SLOT = 0x953adea603236911acee8484929f7f653eda9d977d12e523b651f8908408a95c;
    bytes32 internal constant _F_TOKEN_INITIAL_WEIGHTS_SLOT = 0x1d534d8ecfcf0eea44e9c2b166581c35ca56bbb8a4f1b76c15bf52876ce5895e;
    bytes32 internal constant _TARGET_COLLATERALIZATION_SLOT = 0x21bd4ad06109fb88c15d4cd366f71d076d5e3e7be67c65e57e481fb37b635336;
    bytes32 internal constant _COLLATERALIZATION_FLEX_PERCENTAGE_SLOT = 0xaa80531865fdaebb3741b8a97a2bec9f8a17de868f5dac601249b28bab693f16;

    uint256 public constant TOTAL_WEIGHT = 1e18;

    // _collateralizationFlexPercentage the % that actual collateralization can flex around `_targetCollateralization`
    //                                  For example. target == 200%, flex == 5%; can range between 190% and 210%

    // ========================= Public Functions =========================

    constructor() public {
        assert(_DOLOMITE_MARGIN_SLOT == bytes32(uint256(keccak256("eip1967.vaultStorage.dolomiteMargin")) - 1));
        assert(_F_TOKENS_SLOT == bytes32(uint256(keccak256("eip1967.vaultStorage.fTokens")) - 1));
        assert(_BORROW_TOKENS_SLOT == bytes32(uint256(keccak256("eip1967.vaultStorage.borrowTokens")) - 1));
        assert(_F_TOKEN_INITIAL_WEIGHTS_SLOT == bytes32(uint256(keccak256("eip1967.vaultStorage.fTokenInitialWeights")) - 1));
        assert(_TARGET_COLLATERALIZATION_SLOT == bytes32(uint256(keccak256("eip1967.vaultStorage.targetCollateralization")) - 1));
        assert(_COLLATERALIZATION_FLEX_PERCENTAGE_SLOT == bytes32(uint256(keccak256("eip1967.vaultStorage.collateralizationFlexPercentage")) - 1));
    }

    function initializeSimpleLeverageStrategy(
        address _storage,
        address _underlying,
        address _vault,
        address _rewardPool,
        address _strategist,
        address dolomiteMargin,
        address[] memory _fTokens,
        address[] memory _borrowTokens,
        uint[] memory _fTokenInitialWeights,
        DolomiteMarginDecimal.D256 memory _targetCollateralization,
        DolomiteMarginDecimal.D256 memory _collateralizationFlexPercentage
    ) public initializer {
        address[] memory _rewardTokens = new address[](0);
        BaseUpgradeableStrategy.initialize(
            _storage,
            _underlying,
            _vault,
            _rewardPool,
            _rewardTokens,
            _strategist
        );

        _setDolomiteMargin(dolomiteMargin);
        _setTokens(_fTokens, _borrowTokens, _fTokenInitialWeights);
        _setTargetCollateralization(_targetCollateralization);
        _setCollateralizationFlexPercentage(_collateralizationFlexPercentage);
    }

    function dolomiteMargin() public view returns (IDolomiteMargin) {
        return IDolomiteMargin(getAddress(_DOLOMITE_MARGIN_SLOT));
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

    /**
     * @return  The user's collateralization, using 18 decimals of precision. This is calculated by dividing the supply
     *          value by the account's borrow value
     */
    function getCollateralization() public view returns (DolomiteMarginDecimal.D256 memory) {
        (
            DolomiteMarginMonetary.Value memory supplyValue,
            DolomiteMarginMonetary.Value memory borrowValue
        ) = dolomiteMargin().getAccountValues(_defaultMarginAccount());

        if (borrowValue.value == 0) {
            return DolomiteMarginDecimal.D256({
                value: uint(-1)
            });
        }

        return DolomiteMarginDecimal.D256({
            value: supplyValue.value.mul(1e18).div(borrowValue.value)
        });
    }

    function rebalanceAssets() external onlyNotPausedInvesting restricted nonReentrant {
        IDolomiteMargin _dolomiteMargin = dolomiteMargin();
        (
            DolomiteMarginMonetary.Value memory supplyValue,
            DolomiteMarginMonetary.Value memory borrowValue
        ) = _dolomiteMargin.getAccountValues(_defaultMarginAccount());

        DolomiteMarginDecimal.D256 memory _targetCollateralization = targetCollateralization();
        if (borrowValue.value == 0) {
            emit RebalanceDenied();
            return; // GUARD STATEMENT
        } else {
            DolomiteMarginDecimal.D256 memory flexPercentage = collateralizationFlexPercentage();
            uint collateralization = supplyValue.value.mul(1e18).div(borrowValue.value);
            if (
                collateralization > _targetCollateralization.value.mul(flexPercentage.onePlus()) ||
                collateralization < _targetCollateralization.value.div(flexPercentage.onePlus())
            ) {
                emit RebalanceDenied();
                return; // GUARD STATEMENT
            }
        }

        DolomiteMarginAccount.Info[] memory accounts = new DolomiteMarginAccount.Info[](1);
        accounts[0] = _defaultMarginAccount();

        uint256[] memory weights = fTokenInitialWeights();
        address[] memory allFTokens = fTokens();
        address[] memory allBorrowTokens = borrowTokens();
        DolomiteMarginActions.ActionArgs[] memory actions = new DolomiteMarginActions.ActionArgs[](weights.length);

        uint targetSupplyValue = borrowValue.value.mul(_targetCollateralization);
        if (supplyValue.value < targetSupplyValue) {
            // rebalance upward, increase leverage
            uint deltaSupplyValue = targetSupplyValue.sub(supplyValue.value);
            for (uint i = 0; i < weights.length; i++) {
                uint weightedSupplyValue = deltaSupplyValue.mul(weights[i]).div(TOTAL_WEIGHT);
                uint borrowMarketId = _dolomiteMargin.getMarketIdByTokenAddress(allBorrowTokens[i]);
                // The supplyValue has 36 decimals, price has (36 - tokenDecimals) decimals, so it's safe to simply
                // divide them and that gives us the proper number of units in the result.
                actions[i] = _encodeSell(
                    weightedSupplyValue.div(_dolomiteMargin.getMarketPrice(borrowMarketId).value),
                    borrowMarketId,
                    _dolomiteMargin.getMarketIdByTokenAddress(allFTokens[i]),
                    i
                );
            }
        } else {
            // rebalance downward, decrease leverage
            assert(supplyValue.value > targetSupplyValue);
            uint deltaSupplyValue = supplyValue.value.sub(targetSupplyValue);
            for (uint i = 0; i < weights.length; i++) {
                uint weightedSupplyValue = deltaSupplyValue.mul(weights[i]).div(TOTAL_WEIGHT);
                uint fMarketId = _dolomiteMargin.getMarketIdByTokenAddress(allFTokens[i]);
                // The supplyValue has 36 decimals, price has (36 - tokenDecimals) decimals, so it's safe to simply
                // divide them and that gives us the proper number of units in the result.
                actions[i] = _encodeSell(
                    weightedSupplyValue.div(_dolomiteMargin.getMarketPrice(fMarketId).value),
                    fMarketId,
                    _dolomiteMargin.getMarketIdByTokenAddress(allBorrowTokens[i]),
                    i
                );
            }
        }

        _dolomiteMargin.operate(accounts, actions);
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
    returns (uint256) {
        require(
            msg.sender == address(dolomiteMargin()) && msg.sender == receiver && tradeOriginator == address(this),
            "unauthorized"
        );
        (uint tokenIndex) = abi.decode(orderData, (uint));
        bool isDeposit;
        {
            address[] memory _fTokens = fTokens();
            address[] memory _borrowTokens = borrowTokens();
            // If the fToken is the makerToken, that's the token to which we're converting
            isDeposit = _fTokens[tokenIndex] == makerToken;
            require(
                (_fTokens[tokenIndex] == makerToken && _borrowTokens[tokenIndex] == takerToken) ||
                (_fTokens[tokenIndex] == takerToken && _borrowTokens[tokenIndex] == makerToken),
                "index not correct"
            );
        }

        uint amount;
        if (isDeposit) {
            amount = IERC4626(makerToken).deposit(requestedFillAmount, address(this));
        } else {
            amount = IERC4626(takerToken).redeem(requestedFillAmount, address(this), address(this));
        }

        return amount;
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

    function _setDolomiteMargin(
        address _dolomiteMargin
    ) internal {
        setAddress(_DOLOMITE_MARGIN_SLOT, _dolomiteMargin);
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

    function _repayLoanAndWithdrawCollateral(
        address[] memory _fTokens,
        address[] memory _borrowTokens
    ) internal {
        IDolomiteMargin _dolomiteMargin = dolomiteMargin();

        DolomiteMarginAccount.Info[] memory accounts = new DolomiteMarginAccount.Info[](1);
        accounts[0] = _defaultMarginAccount();
        {
            if (dolomiteMargin().getAccountMarketsWithNonZeroBalances(_defaultMarginAccount()).length == 0) {
                // loan and collateral already repaid.
                return;
            }
        }

        address[] memory allFTokens = fTokens();
        address[] memory allBorrowTokens = borrowTokens();
        DolomiteMarginActions.ActionArgs[] memory actions = new DolomiteMarginActions.ActionArgs[](
            allFTokens.length + allFTokens.length
        );

        for (uint i = 0; i < allFTokens.length; i++) {
            uint fMarketId = _dolomiteMargin.getMarketIdByTokenAddress(allFTokens[i]);
            actions[i * 2] = _encodeBuy(
            );
            actions[(i * 2) + 1] = _encodeWithdraw(uint(-1), fMarketId);
        }
    }

    function _withdrawFromDolomite(uint _tokenIndex, uint _fAmount) internal {

    }

    function _setAllowanceForAll(address[] memory _tokens, uint _allowance) internal {
        address _dolomiteMargin = address(dolomiteMargin());
        for (uint i = 0; i < _tokens.length; i++) {
            if (_allowance > 0) {
                // reset to 0 first
                IERC20(_tokens[i]).safeApprove(_dolomiteMargin, 0);
            }
            IERC20(_tokens[i]).safeApprove(_dolomiteMargin, _allowance);
        }
    }
}
