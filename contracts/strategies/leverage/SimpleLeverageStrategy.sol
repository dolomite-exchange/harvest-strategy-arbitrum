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

import "./SimpleLeverageStrategyStorage.sol";
import "../../base/dolomite/lib/DolomiteMarginActions.sol";


/**
 * @dev Utilizes borrowed assets to perform a delta-neutral strategy, where the delta between the supply rate of
 *      supplied assets and the borrow rate of borrowed assets is arbitraged for amplified yield.
 */
contract SimpleLeverageStrategy is IStrategy, SimpleLeverageStrategyStorage, IDolomiteExchangeWrapper {
    using DolomiteMarginDecimal for *;
    using SafeMath for uint256;

    // ========================= Events =========================

    event RebalanceAssets(
        DolomiteMarginDecimal.D256 previousCollateralization,
        DolomiteMarginDecimal.D256 currentCollateralization
    );
    event RebalanceDenied(
        DolomiteMarginDecimal.D256 currentCollateralization
    );

    // _collateralizationFlexPercentage the % that actual collateralization can flex around `_targetCollateralization`
    //                                  For example. target == 200%, flex == 5%; can range between 190% and 210%

    // ========================= Public Functions =========================

    function initializeSimpleLeverageStrategy(
        address _storage,
        address _underlying,
        address _vault,
        address _rewardPool,
        address _strategist,
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

        IERC20(underlying()).safeApprove(rewardPool(), uint(-1));
        _setTokens(_fTokens, _borrowTokens, _fTokenInitialWeights);
        _setTargetCollateralization(_targetCollateralization);
        _setCollateralizationFlexPercentage(_collateralizationFlexPercentage);
    }

    function isWithinRange(
        uint256 _collateralization,
        DolomiteMarginDecimal.D256 memory _targetCollateralization,
        DolomiteMarginDecimal.D256 memory _flexPercentage
    ) public pure returns (bool) {
        return _collateralization <= _targetCollateralization.value.mul(_flexPercentage.onePlus()) &&
            _collateralization >= _targetCollateralization.value.div(_flexPercentage.onePlus());
    }

    /**
     * @dev Rebalances the asserts held by this vault to move within the target collateralization range. If there is no
     *      debt or if the collateralization is within the target range, no rebalance occurs.
     */
    function rebalanceAssets() external onlyNotPausedInvesting restricted nonReentrant {
        IDolomiteMargin _dolomiteMargin = IDolomiteMargin(rewardPool());
        (
            DolomiteMarginMonetary.Value memory supplyValue,
            DolomiteMarginMonetary.Value memory borrowValue
        ) = _dolomiteMargin.getAccountValues(_defaultMarginAccount());

        DolomiteMarginDecimal.D256 memory _targetCollateralization = targetCollateralization();
        if (borrowValue.value == 0) {
            emit RebalanceDenied(DolomiteMarginDecimal.D256(uint(-1)));
            return; // GUARD STATEMENT
        } else {
            DolomiteMarginDecimal.D256 memory flexPercentage = collateralizationFlexPercentage();
            uint collateralization = supplyValue.value.mul(1e18).div(borrowValue.value);
            if (isWithinRange(collateralization, _targetCollateralization, flexPercentage)) {
                emit RebalanceDenied(DolomiteMarginDecimal.D256(collateralization));
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
            // rebalance upward, increase leverage; Delta is the amount of supplied value we need
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
            // rebalance downward, decrease leverage; Delta is the amount of supplied value we need to
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

    function doHardWork() external onlyNotPausedInvesting restricted nonReentrant {
        // TODO - check borrow value change; supply value change; cache it; get the delta and sell it
    }

    function changeLoanStatus(
        bool _shouldCloseLoan
    ) external onlyNotPausedInvesting restricted nonReentrant {
        IDolomiteMargin _dolomiteMargin = IDolomiteMargin(rewardPool());
        {
            (
                ,
                DolomiteMarginMonetary.Value memory borrowValue
            ) = _dolomiteMargin.getAccountValues(_defaultMarginAccount());
            if (_shouldCloseLoan) {
                Require.that(
                    borrowValue.value > 0,
                    FILE,
                    "loan already closed"
                );
            } else {
                Require.that(
                    borrowValue.value == 0,
                    FILE,
                    "loan already opened"
                );
            }
        }

        address[] memory allFTokens = fTokens();
        address[] memory allBorrowTokens = borrowTokens();

        if (_shouldCloseLoan) {
            _repayLoanAndWithdrawCollateral(allFTokens, allBorrowTokens);
        } else {
            DolomiteMarginAccount.Info[] memory accounts = new DolomiteMarginAccount.Info[](1);
            accounts[0] = _defaultMarginAccount();

            DolomiteMarginActions.ActionArgs[] memory actions = new DolomiteMarginActions.ActionArgs[](1);
            actions[0] = _encodeDeposit(IERC20(underlying()).balanceOf(address(this)));
            _dolomiteMargin.operate(accounts, actions);

            actions = new DolomiteMarginActions.ActionArgs[](allFTokens.length);
            (
                DolomiteMarginMonetary.Value memory supplyValue,
            ) = _dolomiteMargin.getAccountValues(_defaultMarginAccount());

            DolomiteMarginDecimal.D256 memory _targetCollateralization = targetCollateralization();
            supplyValue.value = supplyValue.value.mul(_targetCollateralization).div(_targetCollateralization.oneMinus());
            uint256[] memory weights = fTokenInitialWeights();
            for (uint i = 0; i < actions.length; i++) {
                uint weightedSupplyValue = supplyValue.value.times(weights[i]).div(1e18);
                actions[i] = _encodeSell(
                    weightedSupplyValue.div(_dolomiteMargin.getMarketPrice(borrowMarketId).value),
                    borrowMarketId,
                    _dolomiteMargin.getMarketIdByTokenAddress(allFTokens[i]),
                    i
                );
            }
        }
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
            msg.sender == address(rewardPool()) && msg.sender == receiver && tradeOriginator == address(this),
            "unauthorized"
        );
        if (requestedFillAmount == 0) {
            return 0;
        }

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

        // Allowance is already set when the tokens are set, so no need to do so here
        uint amount;
        if (isDeposit) {
            amount = IERC4626(makerToken).deposit(requestedFillAmount, address(this));
        } else {
            amount = IERC4626(takerToken).redeem(requestedFillAmount, address(this), address(this));
        }

        return amount;
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
        if (desiredMakerToken == 0) {
            return 0;
        }

        (uint tokenIndex) = abi.decode(orderData, (uint));
        bool isDepositIntoVault;
        {
            address[] memory _fTokens = fTokens();
            address[] memory _borrowTokens = borrowTokens();
            // If the fToken is the makerToken, that's the token to which we're converting
            isDepositIntoVault = _fTokens[tokenIndex] == makerToken;
            require(
                (_fTokens[tokenIndex] == makerToken && _borrowTokens[tokenIndex] == takerToken) ||
                (_fTokens[tokenIndex] == takerToken && _borrowTokens[tokenIndex] == makerToken),
                "index not correct"
            );
        }

        if (isDepositIntoVault) {
            uint assets = IERC4626(makerToken).previewMint(desiredMakerToken);
            if (IERC4626(takerToken).previewWithdraw(assets) != desiredMakerToken) {
                return assets + 1;
            } else {
                return assets;
            }
        } else {
            // Account for any lossy truncation that occurs when converting
            uint shares = IERC4626(takerToken).previewWithdraw(desiredMakerToken);
            if (IERC4626(takerToken).previewMint(shares) != desiredMakerToken) {
                return shares + 1;
            } else {
                return shares;
            }
        }
    }

    // ========================= Internal Functions =========================

    function _finalizeUpgrade() internal {}

    function _claimRewards() internal {
        IDolomiteMargin _dolomiteMargin = IDolomiteMargin(rewardPool());
        address[] memory _fTokens = fTokens();
        address[] memory _borrowTokens = borrowTokens();

        DolomiteMarginAccount.Info[] memory accounts = new DolomiteMarginAccount.Info[](1);
        accounts[0] = _defaultMarginAccount();

        DolomiteMarginActions.ActionArgs[] memory actions = new DolomiteMarginActions.ActionArgs[](_fTokens.length);

        DolomiteMarginDecimal.D256 memory ONE_PERCENT = DolomiteMarginDecimal.D256(0.01e18);
        for (uint i = 0; i < _fTokens.length; i++) {
            uint256 unit = IVault(_fTokens[i]).underlyingUnit();
            uint256 fTokenMarketId = _dolomiteMargin.getMarketIdByTokenAddress(_fTokens[i]);
            uint256 borrowTokenMarketId = _dolomiteMargin.getMarketIdByTokenAddress(_borrowTokens[i]);

            uint256 newPriceFullShare = IVault(_fTokens[i]).getPricePerFullShare();
            uint256 oldPriceFullShare = cachedPricePerShare(_fTokens[i]);
            uint256 supplyValueGained = 0;
            if (newPriceFullShare > oldPriceFullShare) {
                uint256 amountInVault = _dolomiteMargin.getAccountWei(accounts[0], fTokenMarketId).value;
                supplyValueGained = (newPriceFullShare - oldPriceFullShare).mul(amountInVault).div(unit);
            }

            uint256 newBorrowValue = _dolomiteMargin.getAccountWei(accounts[0], borrowTokenMarketId).value;
            uint256 oldBorrowValue = cachedBorrowWei(_borrowTokens[i]);
            uint256 borrowValueGained = 0;
            if (newBorrowValue > oldBorrowValue) {
                borrowValueGained = newBorrowValue - oldBorrowValue;
            }

            uint256 amountWei = supplyValueGained > borrowValueGained ? supplyValueGained - borrowValueGained : 0;

            // trim 1% as a buffer to not bankrupt profits from dynamic borrow rates
            amountWei = amountWei.sub(amountWei.mul(ONE_PERCENT));

            actions[i] = _encodeWithdraw(amountWei, fTokenMarketId);
        }
    }

    function _rewardPoolBalance() internal view returns (uint256) {
        IDolomiteMargin _dolomiteMargin = IDolomiteMargin(rewardPool());
        uint256 marketId = _dolomiteMargin.getMarketIdByTokenAddress(underlying());
        return _dolomiteMargin.getAccountWei(_defaultMarginAccount(), marketId).value;
    }

    function _liquidateReward() internal {
        address[] memory buybackTokens = new address[](1);
        buybackTokens[0] = underlying();

        address[] memory _fTokens = fTokens();
        address[] memory _borrowTokens = borrowTokens();

        for (uint i = 0; i < _fTokens.length; i++) {
            // perform the buyback in borrow token after withdrawing from the vault
            IVault(_fTokens[i]).withdraw(IVault(_fTokens[i]).balanceOf(address(this)));
            _notifyProfitAndBuybackInRewardToken(
                _borrowTokens[i],
                IERC20(_borrowTokens[i]).balanceOf(address(this)),
                buybackTokens
            );
        }
    }

    function _partialExitRewardPool(uint256 _amount) internal {
        IDolomiteMargin _dolomiteMargin = IDolomiteMargin(rewardPool());
        uint256 marketId = _dolomiteMargin.getMarketIdByTokenAddress(underlying());

        // First see if we can withdraw while staying within our target collateralization range. That would simplify
        // things.
        (
            DolomiteMarginMonetary.Value memory supplyValue,
            DolomiteMarginMonetary.Value memory borrowValue
        ) = _dolomiteMargin.getAccountValues(_defaultMarginAccount());

        supplyValue.value = supplyValue.value.sub(_dolomiteMargin.getMarketPrice(marketId).value.mul(_amount));
        if (borrowValue.value > 0) {
            uint256 collateralization = supplyValue.value.mul(1e18).div(borrowValue.value);
            DolomiteMarginDecimal.D256 memory _targetCollateralization = targetCollateralization();
            DolomiteMarginDecimal.D256 memory _flexPercentage = collateralizationFlexPercentage();
            if (isWithinRange(collateralization, _targetCollateralization, _flexPercentage)) {
                DolomiteMarginAccount.Info[] memory accounts = new DolomiteMarginAccount.Info[](1);
                accounts[0] = _defaultMarginAccount();

                DolomiteMarginActions.ActionArgs[] memory actions = new DolomiteMarginActions.ActionArgs[](1);
                actions[0] = _encodeWithdraw(_amount, marketId);

                _dolomiteMargin.operate(accounts, actions);
            } else {
                // Crap this move would put us out of our target collateralization range. We have more work to do!
            }
        } else {
            DolomiteMarginAccount.Info[] memory accounts = new DolomiteMarginAccount.Info[](1);
            accounts[0] = _defaultMarginAccount();

            DolomiteMarginActions.ActionArgs[] memory actions = new DolomiteMarginActions.ActionArgs[](1);
            actions[0] = _encodeWithdraw(_amount, marketId);

            _dolomiteMargin.operate(accounts, actions);
        }
    }

    function _enterRewardPool() internal {
        IDolomiteMargin _dolomiteMargin = IDolomiteMargin(rewardPool());

        DolomiteMarginAccount.Info[] memory accounts = new DolomiteMarginAccount.Info[](1);
        accounts[0] = _defaultMarginAccount();

        DolomiteMarginActions.ActionArgs[] memory actions = new DolomiteMarginActions.ActionArgs[](1);
        actions[0] = _encodeDeposit(
            IERC20(underlying()).balanceOf(address(this)),
            _dolomiteMargin.getMarketIdByTokenAddress(underlying())
        );

        _dolomiteMargin.operate(accounts, actions);
    }

    function _repayLoanAndWithdrawCollateral(
        address[] memory _fTokens,
        address[] memory _borrowTokens
    ) internal {
        IDolomiteMargin _dolomiteMargin = IDolomiteMargin(rewardPool());

        DolomiteMarginAccount.Info[] memory accounts = new DolomiteMarginAccount.Info[](1);
        accounts[0] = _defaultMarginAccount();
        {
            if (_dolomiteMargin.getAccountMarketsWithNonZeroBalances(accounts[0]).length == 0) {
                // loan and collateral already repaid.
                emit RebalanceDenied(DolomiteMarginDecimal.D256({
                    value: 0
                }));
                return;
            }
        }

        DolomiteMarginActions.ActionArgs[] memory actions = new DolomiteMarginActions.ActionArgs[](_fTokens.length * 2);

        for (uint i = 0; i < _fTokens.length; i++) {
            uint fMarketId = _dolomiteMargin.getMarketIdByTokenAddress(_fTokens[i]);
            uint borrowMarketId = _dolomiteMargin.getMarketIdByTokenAddress(_borrowTokens[i]);
            // purchase down all remaining debt for each market
            actions[i * 2] = _encodeBuy(
                _dolomiteMargin.getAccountWei(accounts[0], borrowMarketId).value,
                fMarketId,
                borrowMarketId,
                i
            );
            actions[(i * 2) + 1] = _encodeWithdraw(uint(-1), fMarketId);
        }

        _dolomiteMargin.operate(accounts, actions);
        _cacheLoanState();
    }

    function _setAllowanceForAll(
        address[] memory _tokens,
        uint _allowance
    ) internal {
        address _dolomiteMargin = rewardPool();
        for (uint i = 0; i < _tokens.length; i++) {
            if (_allowance > 0) {
                // reset to 0 first
                IERC20(_tokens[i]).safeApprove(_dolomiteMargin, 0);
            }
            IERC20(_tokens[i]).safeApprove(_dolomiteMargin, _allowance);
        }
    }
}
