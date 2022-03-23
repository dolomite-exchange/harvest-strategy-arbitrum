pragma solidity ^0.5.16;

import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import "./inheritance/Constants.sol";
import "./interfaces/IController.sol";
import "./interfaces/weth/IWETH.sol";
import "./VaultV2.sol";


contract VaultV2Payable is Constants, ReentrancyGuard {
    using Address for address payable;

    // ========================= Events =========================

    event OperatorSet(address indexed owner, address indexed operator, bool isTrusted);

    // ========================= Fields =========================

    address public vault;
    mapping(address => mapping(address => bool)) public trustedOperators;

    modifier defense() {
        require(
            (msg.sender == tx.origin) || // If it is a normal user and not smart contract,
            // then the requirement will pass
            !IController(controller()).greyList(msg.sender), // If it is a smart contract, then
            "This smart contract has been grey listed"  // make sure that it is not on our greyList.
        );
        _;
    }

    constructor(address _vault) public {
        require(VaultV2(_vault).underlying() == WETH, "invalid underlying");

        vault = _vault;
        IWETH(WETH).approve(_vault, uint(- 1));
    }

    function() external payable {
        require(msg.sender == WETH, "invalid sender for default payable");
    }

    function controller() public view returns (address) {
        return VaultV2(vault).controller();
    }

    function depositWithETH(
        address _receiver
    )
    external
    nonReentrant
    defense
    payable
    returns (uint256 shares) {
        require(
            _receiver != address(this),
            "cannot deposit to this contract"
        );
        require(
            msg.value > 0,
            "not enough ETH sent"
        );

        IWETH(WETH).deposit.value(msg.value)();
        shares = VaultV2(vault).deposit(msg.value, _receiver);
    }

    function withdrawToETH(
        uint256 _assets,
        address _receiver,
        address _owner
    )
    external
    nonReentrant
    defense
    returns (uint256 shares) {
        require(
            _receiver != address(this),
            "cannot withdraw to this contract"
        );
        _checkOperator(_owner);

        shares = VaultV2(vault).withdraw(_assets, address(this), _owner);

        IWETH(WETH).withdraw(_assets);
        Address.toPayable(_receiver).sendValue(_assets);
    }

    function redeemToETH(
        uint256 _shares,
        address _receiver,
        address _owner
    )
    public
    nonReentrant
    defense
    returns (uint256 assets) {
        require(
            _receiver != address(this),
            "cannot redeem to this contract"
        );
        _checkOperator(_owner);

        assets = VaultV2(vault).redeem(_shares, address(this), _owner);
        IWETH(WETH).withdraw(assets);
        Address.toPayable(_receiver).sendValue(assets);
    }

    function setTrustedOperator(address _operator, bool _isTrusted) external {
        trustedOperators[msg.sender][_operator] = _isTrusted;
        emit OperatorSet(msg.sender, _operator, _isTrusted);
    }

    // ========================= Internal Functions =========================

    function _checkOperator(address _owner) internal view {
        require(
            _owner == msg.sender || trustedOperators[_owner][msg.sender],
            "VaultV2PayableProxy: msg.sender is not a trusted operator for owner"
        );
    }

}

