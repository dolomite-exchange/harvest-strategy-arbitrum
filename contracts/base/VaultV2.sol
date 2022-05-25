pragma solidity ^0.5.16;

import "./interfaces/IERC4626.sol";
import "./VaultV1.sol";


contract VaultV2 is IERC4626, VaultV1 {

    /// By default, the constant `10` is a uint8. This implicitly converts it to `uint256`
    uint256 public constant TEN = 10;

    function asset() public view returns (address) {
        return underlying();
    }

    function totalAssets() public view returns (uint256) {
        return underlyingBalanceWithInvestment();
    }

    function assetsPerShare() public view returns (uint256) {
        return _sharesToAssets(TEN ** decimals());
    }

    function assetsOf(address _depositor) public view returns (uint256) {
        return totalAssets() * balanceOf(_depositor) / totalSupply();
    }

    function maxDeposit(address /*caller*/) public view returns (uint256) {
        return uint(-1);
    }

    function previewDeposit(uint256 _assets) public view returns (uint256) {
        return _assetsToShares(_assets);
    }

    function deposit(uint256 _assets, address _receiver) public nonReentrant defense returns (uint256) {
        uint shares = previewDeposit(_assets);
        _deposit(_assets, msg.sender, _receiver);
        return shares;
    }

    function maxMint(address /*caller*/) public view returns (uint256) {
        return uint(-1);
    }

    function previewMint(uint256 _shares) public view returns (uint256) {
        return _sharesToAssets(_shares);
    }

    function mint(uint256 _shares, address _receiver) public nonReentrant defense returns (uint256) {
        uint assets = previewMint(_shares);
        _deposit(assets, msg.sender, _receiver);
        return assets;
    }

    function maxWithdraw(address _caller) public view returns (uint256) {
        return assetsOf(_caller);
    }

    function previewWithdraw(uint256 _assets) public view returns (uint256) {
        return _assetsToShares(_assets);
    }

    function withdraw(
        uint256 _assets,
        address _receiver,
        address _owner
    )
    public
    nonReentrant
    defense
    returns (uint256) {
        uint256 shares = previewWithdraw(_assets);
        _withdraw(shares, _receiver, _owner);
        return shares;
    }

    function maxRedeem(address _caller) public view returns (uint256) {
        return balanceOf(_caller);
    }

    function previewRedeem(uint256 _shares) public view returns (uint256) {
        return _sharesToAssets(_shares);
    }

    function redeem(
        uint256 _shares,
        address _receiver,
        address _owner
    )
    public
    nonReentrant
    defense
    returns (uint256) {
        uint256 assets = _withdraw(_shares, _receiver, _owner);
        return assets;
    }

    // ========================= Internal Functions =========================

    function _sharesToAssets(uint256 _shares) internal view returns (uint256) {
        return totalAssets() == 0 || totalSupply() == 0
            ? _shares * (TEN ** ERC20Detailed(underlying()).decimals()) / (TEN ** decimals())
            : _shares * totalAssets() / totalSupply();
    }

    function _assetsToShares(uint256 _assets) internal view returns (uint256) {
        return totalAssets() == 0 || totalSupply() == 0
            ? _assets * (TEN ** decimals()) / (TEN ** ERC20Detailed(underlying()).decimals())
            : _assets * totalSupply() / totalAssets();
    }
}
