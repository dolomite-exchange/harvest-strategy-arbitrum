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

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./interfaces/IDolomiteMargin.sol";

import "./lib/DolomiteMarginAccount.sol";
import "./lib/DolomiteMarginActionsHelper.sol";
import "./lib/Require.sol";

import "./AssetTransformerInternal.sol";
import "./LeveragedNoMintPotPool.sol";

contract DolomiteYieldFarmingMarginRouter is ReentrancyGuard, IAssetTransformerInternal {
    using DolomiteMarginActionsHelper for *;
    using SafeERC20 for IERC20;
    using SafeMath for uint;
    using Require for *;

    bytes32 public constant FILE = "DolomiteYieldFarmingMarginRouter";
    uint256 public constant MAX_UINT = uint(- 1);

    IDolomiteMargin public dolomiteMargin;
    AssetTransformerInternal public transformerInternal;

    constructor(
        address _dolomiteMargin,
        address _transformerInternal
    ) public {
        dolomiteMargin = IDolomiteMargin(_dolomiteMargin);
        transformerInternal = AssetTransformerInternal(_transformerInternal);
    }

    /**
     * @param _depositTokens    The tokens the user is depositing as collateral.
     * @param _depositAmounts   The amounts of `_depositTokens` the user is depositing as collateral.
     * @param _borrowTokens     The tokens the user is borrowing to amplify the position
     * @param _borrowAmounts    The amounts of `_borrowTokens` the user is borrowing
     * @param _transformer      The contract that will perform the transformation from `_depositTokens` +
     *                          `_borrowTokens` to `fToken`
     * @param _stakingPool      The pool to which the resulting fToken will be staked after
     * @param _extraData        Extra encoded data to be passed along to the transformer. Can be used for checking
     *                          slippage, deadlines, etc.
     */
    function startFarming(
        address[] memory _depositTokens,
        uint[] memory _depositAmounts,
        address[] memory _borrowTokens,
        uint[] memory _borrowAmounts,
        address _transformer,
        address _stakingPool,
        bytes memory _extraData
    )
    public
    nonReentrant {
        Require.that(
            _depositTokens.length == _depositAmounts.length,
            FILE,
            "invalid deposit amounts length"
        );
        Require.that(
            _borrowTokens.length == _borrowAmounts.length,
            FILE,
            "invalid borrow amounts length"
        );

        address fToken = IDolomiteAssetTransformer(_transformer).fToken();
        Require.that(
            fToken == LeveragedNoMintPotPool(_stakingPool).lpToken(),
            FILE,
            "staking pool fToken mismatch"
        );

        (
            address[] memory allTokens,
            uint[] memory allAmounts
        ) = _getAllTokensAndAmountsFromDepositAndBorrowTokens(
            _depositTokens,
            _depositAmounts,
            _borrowTokens,
            _borrowAmounts
        );

        _transferTokensInAndApproveIfNecessary(_depositTokens, _depositAmounts);

        DolomiteMarginAccount.Info[] memory accounts = new DolomiteMarginAccount.Info[](1);
        accounts[0] = DolomiteMarginAccount.Info({
            owner: _stakingPool,
            number: LeveragedNoMintPotPool(_stakingPool).getAccountNumber(msg.sender, 0)
        });

        IDolomiteMargin _dolomiteMargin = dolomiteMargin; // save gas costs by reading into memory once

        // actions.length == borrowToken withdrawals + DolomiteMargin::CALL + DolomiteMargin::DEPOSIT
        DolomiteMarginActions.ActionArgs[] memory actions = new DolomiteMarginActions.ActionArgs[](
            _borrowTokens.length + 2
        );
        for (uint i = 0; i < _borrowAmounts.length; i++) {
            actions[i] = DolomiteMarginActionsHelper.createWithdrawal(
                /* accountIndex = */ 0,
                _dolomiteMargin.getMarketIdByTokenAddress(_borrowTokens[i]),
                address(transformerInternal),
                _borrowAmounts[i]
            );
        }
        // Call the transformer, notifying it of the tokens and amounts it will receive in exchange for fToken
        // The call to transformer should send the fTokens to address(this) for the subsequent deposit
        actions[_borrowAmounts.length] = DolomiteMarginActionsHelper.createCall(
            /* accountIndex = */ 0,
            address(transformerInternal),
            abi.encode(
                TransformationType.TRANSFORM,
                // msg.sender serves as a dust recipient here
                abi.encode(_transformer, fToken, allTokens, allAmounts, msg.sender, _extraData)
            )
        );

        // Deposit the converted fToken into DolomiteMargin from this contract
        uint fAmountWei = IDolomiteAssetTransformer(_transformer).getTransformationResult(allTokens, allAmounts);
        actions[_borrowAmounts.length + 1] = DolomiteMarginActionsHelper.createDeposit(
            /* accountIndex = */ 0,
            IDolomiteMargin(_dolomiteMargin).getMarketIdByTokenAddress(fToken),
            address(this),
            fAmountWei
        );

        // approve the fToken to be transferred into DolomiteMargin from this contract
        IERC20(fToken).approve(address(_dolomiteMargin), 0);
        IERC20(fToken).approve(address(_dolomiteMargin), fAmountWei);

        _dolomiteMargin.operate(accounts, actions);

        // notify the staking pool of the received tokens that are now being staked
        LeveragedNoMintPotPool(_stakingPool).notifyStake(msg.sender, 0, fAmountWei);
    }

    /**
     * @param _fAmountWei           The amount of `fToken` to be converted back to `_outputTokens`. Setting to MAX_UINT
     *                              withdraws the user's full balance
     * @param _outputTokens         The tokens to which `fToken` will be converted
     * @param _withdrawalAmounts    The amounts to be withdrawn to the user from the DolomiteMargin protocol.
     * @param _transformer          The contract that will perform the transformation from `fToken` to `_outputTokens`.
     * @param _stakingPool          The pool from which the `fToken` will be withdrawn if the user is staking. Can be
     *                              `address(0)` meaning the `fToken` will be withdrawn from `msg.sender`.
     * @param _extraData            Extra encoded data to be passed along to the transformer. Can be used for checking
     *                              slippage, deadlines, etc.
     */
    function endFarming(
        uint _fAmountWei,
        address[] memory _outputTokens,
        DolomiteMarginTypes.AssetAmount[] memory _withdrawalAmounts,
        address _transformer,
        address _stakingPool,
        bytes memory _extraData
    )
    public
    nonReentrant {
        Require.that(
            _outputTokens.length == _withdrawalAmounts.length,
            FILE,
            "invalid withdrawalAmounts length"
        );

        address fToken = IDolomiteAssetTransformer(_transformer).fToken();
        Require.that(
            fToken == LeveragedNoMintPotPool(_stakingPool).lpToken(),
            FILE,
            "staking pool fToken mismatch"
        );

        LeveragedNoMintPotPool(_stakingPool).notifyWithdraw(msg.sender, 0, _fAmountWei);

        IDolomiteMargin _dolomiteMargin = dolomiteMargin; // save gas costs
        DolomiteMarginAccount.Info[] memory accounts = new DolomiteMarginAccount.Info[](1);
        {
            accounts[0] = DolomiteMarginAccount.Info({
            owner: _stakingPool,
            number: LeveragedNoMintPotPool(_stakingPool).getAccountNumber(msg.sender, 0)
            });
        }

        // actions.length == WITHDRAW + CALL + DEPOSIT-outputTokens.length + WITHDRAW-outputTokens.length
        DolomiteMarginActions.ActionArgs[] memory actions = new DolomiteMarginActions.ActionArgs[](
            2 + (_outputTokens.length * 2)
        );

        // withdraw the fToken to the transformer
        {
            uint fMarketId = _dolomiteMargin.getMarketIdByTokenAddress(fToken);
            _fAmountWei = _fAmountWei == MAX_UINT
                ? _dolomiteMargin.getAccountWei(accounts[0], fMarketId).value
                : _fAmountWei;
            actions[0] = DolomiteMarginActionsHelper.createWithdrawal(
                /* accountIndex = */ 0,
                fMarketId,
                address(transformerInternal),
                _fAmountWei
            );
        }

        // Create the CALL to transformerInternal; the outputted tokens and their amounts should be sent to
        // address(this) for the deposit to work
        actions[1] = DolomiteMarginActionsHelper.createCall(
            /* accountIndex = */ 0,
            address(transformerInternal),
            abi.encode(
                TransformationType.REVERT,
                abi.encode(_transformer, fToken, _fAmountWei, _outputTokens, _extraData)
            )
        );

        uint[] memory outputMarketIds = _mapTokensToMarketIds(_outputTokens, _dolomiteMargin);
        uint[] memory outputAmounts = IDolomiteAssetTransformer(_transformer).getTransformBackResult(
            _fAmountWei,
            _outputTokens
        );

        // deposit the converted tokens back into DolomiteMargin
        for (uint i = 0; i < _outputTokens.length; i++) {
            // approve the output token to be transferred into DolomiteMargin from this contract
            IERC20(_outputTokens[i]).approve(address(_dolomiteMargin), 0);
            IERC20(_outputTokens[i]).approve(address(_dolomiteMargin), outputAmounts[i]);

            actions[2 + i] = DolomiteMarginActionsHelper.createDeposit(
                /* accountIndex = */ 0,
                outputMarketIds[i],
                address(this),
                outputAmounts[i]
            );
        }

        // withdraw the amounts the user specified to msg.sender
        for (uint i = 0; i < _outputTokens.length; i++) {
            actions[2 + _outputTokens.length + i] = DolomiteMarginActionsHelper.createWithdrawalWithAssetAmount(
                /* accountIndex = */ 0,
                outputMarketIds[i],
                msg.sender,
                _withdrawalAmounts[i]
            );
        }

        _dolomiteMargin.operate(accounts, actions);
    }

    function _mapTokensToMarketIds(
        address[] memory _tokens,
        IDolomiteMargin _dolomiteMargin
    ) internal view returns (uint[] memory) {
        uint[] memory outputMarketIds = new uint[](_tokens.length);
        for (uint i = 0; i < _tokens.length; i++) {
            outputMarketIds[i] = _dolomiteMargin.getMarketIdByTokenAddress(_tokens[i]);
        }
        return outputMarketIds;
    }

    function _transferTokensInAndApproveIfNecessary(
        address[] memory _tokens,
        uint[] memory _amounts
    ) internal {
        address _transformerInternal = address(transformerInternal);
        for (uint i = 0; i < _tokens.length; i++) {
            IERC20(_tokens[i]).safeTransferFrom(msg.sender, address(this), _amounts[i]);
            IERC20(_tokens[i]).safeApprove(_transformerInternal, 0);
            IERC20(_tokens[i]).safeApprove(_transformerInternal, _amounts[i]);
        }
    }

    function _getAllTokensAndAmountsFromDepositAndBorrowTokens(
        address[] memory _depositTokens,
        uint[] memory _depositAmounts,
        address[] memory _borrowTokens,
        uint[] memory _borrowAmounts
    ) internal pure returns (address[] memory, uint[] memory) {
        uint uniqueCount = 0;
        address[] memory allTokens = new address[](_depositTokens.length + _borrowTokens.length);
        uint[] memory allAmounts = new uint[](_depositAmounts.length + _borrowAmounts.length);
        for (uint i = 0; i < _depositTokens.length; i++) {
            uint index = _linearSearch(allTokens, _depositTokens[i]);
            if (index != MAX_UINT) {
                allTokens[uniqueCount] = _depositTokens[i];
                allAmounts[uniqueCount] = _depositAmounts[i];
                uniqueCount += 1;
            } else {
                allAmounts[index] = allAmounts[index].add(_depositAmounts[i]);
            }
        }
        for (uint i = 0; i < _borrowTokens.length; i++) {
            uint index = _linearSearch(allTokens, _borrowTokens[i]);
            if (index != MAX_UINT) {
                allTokens[uniqueCount] = _borrowTokens[i];
                allAmounts[uniqueCount] = _borrowAmounts[i];
                uniqueCount += 1;
            } else {
                // the token already exists; add the amount to allAmounts
                allAmounts[index] = allAmounts[index].add(_borrowAmounts[i]);
            }
        }

        return (_compressAddressArray(allTokens, uniqueCount), _compressUintArray(allAmounts, uniqueCount));
    }

    function _linearSearch(address[] memory tokens, address searchToken) internal pure returns (uint) {
        for (uint i = 0; i < tokens.length; i++) {
            if (tokens[i] == searchToken) {
                return i;
            }
        }
        return MAX_UINT;
    }

    function _compressAddressArray(address[] memory tokens, uint realSize) internal pure returns (address[] memory) {
        address[] memory newTokens = new address[](realSize);
        for (uint i = 0; i < newTokens.length; i++) {
            newTokens[i] = tokens[i];
        }
        return newTokens;
    }

    function _compressUintArray(uint[] memory amounts, uint realSize) internal pure returns (uint[] memory) {
        uint[] memory newAmounts = new uint[](realSize);
        for (uint i = 0; i < newAmounts.length; i++) {
            newAmounts[i] = amounts[i];
        }
        return newAmounts;
    }
}
