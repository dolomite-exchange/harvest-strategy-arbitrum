pragma solidity ^0.5.16;

import "@openzeppelin/contracts-ethereum-package/contracts/utils/Address.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts-ethereum-package/contracts/token/ERC20/IERC20.sol";

import "./inheritance/Governable.sol";
import "./interfaces/IProfitSharingReceiver.sol";


/**
 * A simple contract for receiving tokens for profit sharing. This contract is designed to pool rewards that will be
 * sent by governance to Ethereum mainnet for FARM buybacks
 */
contract ProfitSharingReceiverV1 is IProfitSharingReceiver, Governable {
    using SafeERC20 for IERC20;

    event WithdrawToken(address indexed token, address indexed receiver, uint amount);

    constructor(
        address _store
    )
    public
    Governable(_store) {}

    function withdrawTokens(address[] calldata _tokens) external onlyGovernance {
        address _governance = governance();
        for (uint i = 0; i < _tokens.length; ++i) {
            uint amount = IERC20(_tokens[i]).balanceOf(address(this));
            if (amount > 0) {
                IERC20(_tokens[i]).safeTransfer(_governance, amount);
                emit WithdrawToken(_tokens[i], _governance, amount);
            }
        }
    }

}
