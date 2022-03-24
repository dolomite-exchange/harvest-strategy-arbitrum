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

import "@openzeppelin/contracts/math/SafeMath.sol";


library AdvancedMath {
    using SafeMath for uint256;

    uint256 internal constant ONE_ETH = 1e18;

    function getGeometricMean(uint256[] memory _values, bool _shouldSort) internal pure returns (uint256) {
        if (_shouldSort) {
            _values = _sort(_values);
        }

        // one of the permutations converges
        uint[][] memory allValuesPermutations = _permute(_values);

        uint valuesLength = _values.length;
        for (uint z = 0; z < allValuesPermutations.length; z++) {
            uint D = allValuesPermutations[z][0];
            uint diff = 0;

            for (uint i = 0; i < 31; ++i) {
                uint D_prev = D;
                uint tmp = ONE_ETH;
                for (uint j = 0; j < valuesLength; ++j) {
                    tmp = tmp * allValuesPermutations[z][j] / D;
                }
                D = D * ((valuesLength - 1) * ONE_ETH + tmp) / (valuesLength * ONE_ETH);
                if (D > D_prev) {
                    diff = D - D_prev;
                } else {
                    diff = D_prev - D;
                }

                if (diff <= 1 || diff * ONE_ETH < D) {
                    return D;
                }
            }
        }

        revert("Did not converge");
    }

    function _sort(uint[] memory _data) private pure returns (uint[] memory) {
        _quickSort(_data, int(0), int(_data.length - 1));
        return _data;
    }

    function _quickSort(uint[] memory arr, int left, int right) private pure {
        int i = left;
        int j = right;
        if (i == j) {
            return;
        }

        uint pivot = arr[uint(left + (right - left) / 2)];
        while (i <= j) {
            while (arr[uint(i)] < pivot) {
                i++;
            }
            while (pivot < arr[uint(j)]) {
                j--;
            }
            if (i <= j) {
                (arr[uint(i)], arr[uint(j)]) = (arr[uint(j)], arr[uint(i)]);
                i++;
                j--;
            }
        }
        if (left < j) {
            _quickSort(arr, left, j);
        }
        if (i < right) {
            _quickSort(arr, i, right);
        }
    }

    function _permute(
        uint256[] memory _values
    ) private pure returns (uint256[][] memory) {
        require(_values.length <= 4, "too many permutations");

        uint numberOfPermutations = 1;
        for (uint i = 2; i <= _values.length; ++i) {
            numberOfPermutations = numberOfPermutations * i;
        }

        uint[][] memory permutations = new uint[][](numberOfPermutations);
        _recursivePermute(0, _values, permutations, 0);
        return permutations;
    }

    function _recursivePermute(
        uint _index,
        uint[] memory _values,
        uint[][] memory _answer,
        uint _answerIndex
    ) private pure returns (uint) {
        if (_index == _values.length) {
            _answer[_answerIndex] = new uint[](_values.length);
            for (uint i = 0; i < _values.length; i++) {
                _answer[_answerIndex][i] = _values[i];
            }
            return _answerIndex + 1;
        }

        for (uint i = _index; i < _values.length; i++) {
            _swap(i, _index, _values);
            _answerIndex = _recursivePermute(_index + 1, _values, _answer, _answerIndex);
            _swap(i, _index, _values);
        }

        return _answerIndex;
    }

    function _swap(uint i, uint j, uint[] memory _values) private pure {
        if (i == j) {
            return;
        }

        uint t = _values[i];
        _values[i] = _values[j];
        _values[j] = t;
    }

}
