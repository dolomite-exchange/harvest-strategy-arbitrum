pragma solidity ^0.5.16;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";


contract TestToken is ERC20, ERC20Detailed {

    constructor (
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) public ERC20Detailed(_name, _symbol, _decimals) {}

    function mint(address _account, uint _amount) public {
        super._mint(_account, _amount);
    }

    function burn(address _account, uint _amount) public {
        super._burn(_account, _amount);
    }

}
