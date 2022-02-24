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

import "./helpers/DolomiteMarginActionHelpers.sol";

import "./interfaces/IDolomiteMargin.sol";

import "./lib/DolomiteMarginAccount.sol";
import "./lib/Require.sol";

import "./AssetTransformerInternal.sol";
import "./LeveragedNoMintPotPool.sol";

contract DolomiteYieldFarmingMarginRouter is ReentrancyGuard, DolomiteMarginActionHelpers {
    using SafeERC20 for IERC20;
    using SafeMath for uint;
    using Require for *;

    bytes32 public constant FILE = "DolomiteYieldFarmingMarginRouter";
    uint256 public constant MAX_UINT = uint(- 1);

    IDolomiteMargin public dolomiteMargin;
    AssetTransformerInternal public transformerInternal;

    constructor(
        address _dolomiteMargin,
        address _transformerInternal,
        address _reverterInternal
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
        ) = _getAllTokensAndAmounts(_depositTokens, _depositAmounts, _borrowTokens, _borrowAmounts);

        uint fAmountWei = IDolomiteAssetTransformer(_transformer).getTransformationResult(allTokens, allAmounts);

        uint fTokenMarketId = IDolomiteMargin(dolomiteMargin).getMarketIdByTokenAddress(fToken);

        address accountOwner = _stakingPool;
        uint accountNumber = LeveragedNoMintPotPool(_stakingPool).getAccountNumber(msg.sender, 0);

        // TODO ERC20::safeTransferFrom _depositTokens into here
        // TODO approve _depositTokens, if necessary, on `transformerInternal`
        // TODO withdraw (borrow) all _borrowAmounts to `transformerInternal`
        // TODO DolomiteMargin::CALL, encoding `allTokens`, `allAmounts`, `_extraData`
        // TODO ERC20::safeTransferFrom `_depositTokens` into `_transformer` via `callFunction.sender`
        // TODO perform transformation logic from _depositTokens + _borrowTokens --> fToken in `_transformer`
        // TODO deposit fToken into DolomiteMargin (_stakingPool, _stakingPool#getAccountNumber), using `fAmountWei`
        // TODO stake upon completion by transferring + notifying `LeveragedNoMintPotPool`

        LeveragedNoMintPotPool(_stakingPool).notifyStake(msg.sender, 0, fAmountWei);
    }

    /**
     * @param _fAmountWei           The amount of `fToken` to be converted back to `_outputTokens`
     * @param _outputTokens         The tokens to which `fToken` will be converted
     * @param _outputAmountsWei     The amounts that should be outputted upon converting to `_outputTokens`, within
     *                              `_slippageTolerance`.
     * @param _slippageTolerance    The slippage tolerance for `_outputAmountsWei`
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
        uint256[] memory _outputAmountsWei,
        Decimal.D256 memory _slippageTolerance,
        DolomiteMarginTypes.AssetAmount[] memory _withdrawalAmounts,
        address _transformer,
        address _stakingPool,
        bytes memory _extraData
    )
    public
    nonReentrant {
        Require.that(
            _outputTokens.length == _outputAmountsWei.length,
            FILE,
            "invalid repayAmounts length"
        );
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

        address accountOwner = _stakingPool;
        uint accountNumber = LeveragedNoMintPotPool(_stakingPool).getAccountNumber(msg.sender, 0);

        // TODO withdraw `_fAmountWei` from msg.sender or `_stakingPool` to `transformer`
        // TODO DolomiteMargin::CALL, encode bytes as data using `_fAmountWei`, `_outputTokens`, and `_extraData`
        // TODO check slippage tolerance of `#getTransformBackResult`
        // TODO deposit `_outputTokens` from `transformerInternal` address using `#getTransformBackResult`
        // TODO use `_withdrawalAmounts` to withdraw all `_outputTokens` back to `msg.sender`
    }

    function _getAllTokensAndAmounts(
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
