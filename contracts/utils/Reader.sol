/*

    Copyright 2022 Dolomite.

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

pragma solidity 0.5.16;

import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";

import "../base/interfaces/IVault.sol";
import "../base/interfaces/IPotPool.sol";


contract Reader {

    function getAllInformation(
        address who,
        address[] memory vaults,
        address[] memory pools
    )
    public view returns (
        uint256[] memory,
        uint256[] memory,
        uint256[] memory
    ) {
        return (unstakedBalances(who, vaults), stakedBalances(who, pools), vaultSharePrices(vaults));
    }

    function unstakedBalances(
        address who,
        address[] memory vaults
    ) public view returns (
        uint256[] memory result
    ) {
        result = new uint256[](vaults.length);
        for (uint256 i = 0; i < vaults.length; i++) {
            result[i] = IVault(vaults[i]).balanceOf(who);
        }
    }

    function stakedBalances(
        address who,
        address[] memory pools
    ) public view returns (
        uint256[] memory result
    ) {
        result = new uint256[](pools.length);
        for (uint256 i = 0; i < pools.length; i++) {
            result[i] = IPotPool(pools[i]).stakedBalanceOf(who);
        }
    }

    function underlyingBalances(
        address who,
        address[] memory vaults
    ) public view returns (
        uint256[] memory result
    ) {
        result = new uint256[](vaults.length);
        for (uint256 i = 0; i < vaults.length; i++) {
            result[i] = IERC20(IVault(vaults[i]).underlying()).balanceOf(who);
        }
    }

    function vaultSharePrices(
        address[] memory vaults
    ) public view returns (
        uint256[] memory result
    ) {
        result = new uint256[](vaults.length);
        for (uint256 i = 0; i < vaults.length; i++) {
            result[i] = IVault(vaults[i]).getPricePerFullShare();
        }
    }

    function underlyingBalanceWithInvestmentForHolder(
        address who,
        address[] memory vaults
    ) public view returns (
        uint256[] memory result
    ) {
        result = new uint256[](vaults.length);
        for (uint256 i = 0; i < vaults.length; i++) {
            result[i] = IVault(vaults[i]).underlyingBalanceWithInvestmentForHolder(who);
        }
    }
}
