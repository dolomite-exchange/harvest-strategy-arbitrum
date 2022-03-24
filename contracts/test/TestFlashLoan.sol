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

pragma solidity ^0.5.16;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

import "../base/inheritance/Constants.sol";
import "../base/interfaces/uniswap/IUniswapV2Factory.sol";
import "../base/interfaces/uniswap/IUniswapV2Pair.sol";
import "../base/interfaces/uniswap/IUniswapV2Router02.sol";


/**
 * @dev This contract is best used by a sub-contract that inherits from it
 */
contract TestFlashLoan is Constants {
    using SafeERC20 for IERC20;

    IUniswapV2Factory public factory = IUniswapV2Factory(IUniswapV2Router02(SUSHI_ROUTER).factory());

    function executeFlashLoan(
        address _tokenA,
        address _tokenB,
        uint _amountA,
        uint _amountB,
        bytes calldata _data
    ) external {
        address pairAddress = factory.getPair(_tokenA, _tokenB);
        (uint amount0, uint amount1) = _tokenA < _tokenB ? (_amountA, _amountB) : (_amountB, _amountA);
        require(pairAddress != address(0), 'There is no such pool');
        IUniswapV2Pair(pairAddress).swap(
            amount0,
            amount1,
            address(this),
            _data
        );
    }

    function uniswapV2Call(
        address _sender,
        uint _amount0,
        uint _amount1,
        bytes calldata _data
    ) external {
        uint amountToken = _amount0 == 0 ? _amount1 : _amount0;

        address token0 = IUniswapV2Pair(msg.sender).token0();
        address token1 = IUniswapV2Pair(msg.sender).token1();

        require(
            _sender == address(this) && msg.sender == factory.getPair(token0, token1),
            'Unauthorized'
        );
        require(
            _amount0 == 0 || _amount1 == 0,
            "Invalid amounts"
        );

        IERC20 token = IERC20(_amount0 == 0 ? token1 : token0);
        _executeFlashLoan(token, amountToken, _data);

        amountToken = (amountToken * 1000 / 997) + 1; // account for origination fees (round up)

        uint amountInContract = token.balanceOf(address(this));
        require(amountInContract > 0, 'Insufficient repayment');
        token.safeTransfer(msg.sender, amountInContract);
        if (amountInContract < amountToken) {
            require(
                token.balanceOf(tx.origin) >= amountToken - amountInContract,
                'Insufficient repayer balance'
            );
            token.safeTransferFrom(tx.origin, msg.sender, amountToken - amountInContract);
        }
    }

    /**
     * @dev Implementor can do anything with `_token` up to `_amount`. When this function returns, `_amount` token (or
     *      greater) must be in this contract, so it can be sent back to the loan's originator
     */
    function _executeFlashLoan(
        IERC20 _token,
        uint256 _amount,
        bytes memory _data
    ) internal;
}
