// SPDX-License-Identifier: MIT

pragma solidity ^0.5.16;


interface IERC4626 {

    // ========================= Events =========================

    /**
     * Caller has exchanged assets for shares, and transferred those shares to owner.
     *
     * MUST be emitted when tokens are deposited into the Vault via the mint and deposit methods.
     */
    event Deposit(address indexed sender, address indexed receiver, uint256 assets, uint256 shares);

    /**
     * Caller has exchanged shares, owned by owner, for assets, and transferred those assets to receiver.
     *
     * MUST be emitted when shares are withdrawn from the Vault in ERC4626.redeem or ERC4626.withdraw methods.
     */
    event Withdraw(address indexed sender, address indexed receiver, uint256 assets, uint256 shares);

    // ========================= Functions =========================

    /**
     * @return The address of the underlying token used for the Vault for accounting, depositing, and withdrawing.
     */
    function asset() external view returns (address assetTokenAddress);

    /**
     * @return  Total amount of the underlying asset that is “managed” by Vault. SHOULD include any compounding that
     *          occurs from yield. MUST be inclusive of any fees that are charged against assets in the Vault.
     */
    function totalAssets() external view returns (uint256 totalManagedAssets);

    /**
     * @return  The amount of underlying the Vault would exchange for 1 unit of shares, in an ideal scenario where all
     *          the conditions are met. MUST NOT be inclusive of any fees that are charged against assets in the Vault.
     *          MUST NOT show any variations depending on the caller. MUST NOT reflect slippage or other on-chain
     *          conditions, when performing the actual exchange. MUST NOT revert unless due to integer overflow caused
     *          by an unreasonably large input. MUST round down towards 0. This calculation MAY NOT reflect the
     *          “per-user” price-per-share, and instead should reflect the “average-user’s” price-per-share, meaning
     *          what the average user should expect to see when exchanging to and from. This function should normally
     *          return more than `10 ** underlying().decimals`.
     */
    function assetsPerShare() external view returns (uint256 assetsPerUnitShare);

    /**
     * @return  Total amount of the underlying asset that is “managed” by Vault for the `depositor`. SHOULD include any
     *          compounding that occurs from yield. MUST be inclusive of any fees that are charged against assets in the
     *          Vault.
     */
    function assetsOf(address depositor) external view returns (uint256 assets);

    /**
     * Maximum amount of the underlying asset that can be deposited into the Vault for the receiver, through a deposit
     * call. MUST return the maximum amount of assets deposit would allow to be deposited for receiver and not cause a
     * revert, which MUST NOT be higher than the actual maximum that would be accepted (it should underestimate if
     * necessary). This assumes that the user has infinite assets, i.e. MUST NOT rely on balanceOf of asset. MUST factor
     * in both global and user-specific limits, like if deposits are entirely disabled (even temporarily) it MUST return
     * 0. MUST return 2 ** 256 - 1 if there is no limit on the maximum amount of assets that may be deposited.
     */
    function maxDeposit(address caller) external view returns (uint256 maxAssets);

    /**
     * Allows an on-chain or off-chain user to simulate the effects of their deposit at the current block, given current
     * on-chain conditions.
     *
     * MUST return as close to and no more than the exact amount of Vault shares that would be
     * minted in a deposit call in the same transaction. I.e. deposit should return the same or more shares as
     * previewDeposit if called in the same transaction. MUST NOT account for deposit limits like those returned from
     * maxDeposit and should always act as though the deposit would be accepted, regardless if the user has enough
     * tokens approved, etc.
     *
     * MUST be inclusive of deposit fees. Integrators should be aware of the existence of deposit fees.
     *
     * MUST NOT revert due to vault specific user/global limits. MAY revert due to other conditions that would also
     * cause deposit to revert.
     *
     * Note that any unfavorable discrepancy between convertToShares and previewDeposit SHOULD be considered slippage in
     * share price or some other type of condition, meaning the depositor will lose assets by depositing.
     */
    function previewDeposit(uint256 assets) external view returns (uint256 shares);

    /**
     * Mints shares Vault shares to receiver by depositing exactly amount of underlying tokens.
     *
     * MUST emit the Deposit event.
     *
     * MUST support ERC-20 approve / transferFrom on asset as a deposit flow. MAY support an additional flow in which
     * the underlying tokens are owned by the Vault contract before the deposit execution, and are accounted for during
     * deposit.
     *
     * MUST revert if all of assets cannot be deposited (due to deposit limit being reached, slippage, the user not
     * approving enough underlying tokens to the Vault contract, etc).
     *
     * Note that most implementations will require pre-approval of the Vault with the Vault’s underlying asset token.
     */
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);

    /**
     * Maximum amount of shares that can be minted from the Vault for the receiver, through a mint call.
     *
     * MUST return the maximum amount of shares mint would allow to be deposited to receiver and not cause a revert,
     * which MUST NOT be higher than the actual maximum that would be accepted (it should underestimate if necessary).
     * This assumes that the user has infinite assets, i.e. MUST NOT rely on balanceOf of asset.
     *
     * MUST factor in both global and user-specific limits, like if mints are entirely disabled (even temporarily) it
     * MUST return 0.
     *
     * MUST return 2 ** 256 - 1 if there is no limit on the maximum amount of shares that may be minted.
     */
    function maxMint(address caller) external view returns (uint256 maxShares);

    /**
     * Allows an on-chain or off-chain user to simulate the effects of their mint at the current block, given current
     * on-chain conditions.
     *
     * MUST return as close to and no fewer than the exact amount of assets that would be deposited in a mint call in
     * the same transaction. I.e. mint should return the same or fewer assets as previewMint if called in the same
     * transaction.
     *
     * MUST NOT account for mint limits like those returned from maxMint and should always act as though the mint would
     * be accepted, regardless if the user has enough tokens approved, etc.
     *
     * MUST be inclusive of deposit fees. Integrators should be aware of the existence of deposit fees.
     *
     * MUST NOT revert due to vault specific user/global limits. MAY revert due to other conditions that would also
     * cause mint to revert.
     *
     * Note that any unfavorable discrepancy between convertToAssets and previewMint SHOULD be considered slippage in
     * share price or some other type of condition, meaning the depositor will lose assets by minting.
     */
    function previewMint(uint256 shares) external view returns (uint256 assets);

    /**
     * Mints exactly shares Vault shares to receiver by depositing amount of underlying tokens.
     *
     * MUST emit the Deposit event.
     *
     * MUST support ERC-20 approve / transferFrom on asset as a mint flow. MAY support an additional flow in which the
     * underlying tokens are owned by the Vault contract before the mint execution, and are accounted for during mint.
     *
     * MUST revert if all of shares cannot be minted (due to deposit limit being reached, slippage, the user not
     * approving enough underlying tokens to the Vault contract, etc).
     *
     * Note that most implementations will require pre-approval of the Vault with the Vault’s underlying asset token.
     */
    function mint(uint256 shares, address receiver) external returns (uint256 assets);

    /**
     * Maximum amount of the underlying asset that can be withdrawn from the owner balance in the Vault, through a
     * withdraw call.
     *
     * MUST return the maximum amount of assets that could be transferred from owner through withdraw and not cause a
     * revert, which MUST NOT be higher than the actual maximum that would be accepted (it should underestimate if
     * necessary).
     *
     * MUST factor in both global and user-specific limits, like if withdrawals are entirely disabled (even temporarily)
     * it MUST return 0.
     */
    function maxWithdraw(address caller) external view returns (uint256 maxAssets);

    /**
     * Allows an on-chain or off-chain user to simulate the effects of their withdrawal at the current block, given
     * current on-chain conditions.
     *
     * MUST return as close to and no fewer than the exact amount of Vault shares that would be burned in a withdraw
     * call in the same transaction. I.e. withdraw should return the same or fewer shares as previewWithdraw if called
     * in the same transaction.
     *
     * MUST NOT account for withdrawal limits like those returned from maxWithdraw and should always act as though the
     * withdrawal would be accepted, regardless if the user has enough shares, etc.
     *
     * MUST be inclusive of withdrawal fees. Integrators should be aware of the existence of withdrawal fees.
     *
     * MUST NOT revert due to vault specific user/global limits. MAY revert due to other conditions that would also
     * cause withdraw to revert.
     *
     * Note that any unfavorable discrepancy between convertToShares and previewWithdraw SHOULD be considered slippage
     * in share price or some other type of condition, meaning the depositor will lose assets by depositing.
     */
    function previewWithdraw(uint256 assets) external view returns (uint256 shares);

    /**
     * Burns shares from owner and sends exactly assets of underlying tokens to receiver.
     *
     * MUST emit the Withdraw event.
     *
     * MUST support a withdraw flow where the shares are burned from owner directly where owner is msg.sender or
     * msg.sender has ERC-20 approval over the shares of owner. MAY support an additional flow in which the shares are
     * transferred to the Vault contract before the withdraw execution, and are accounted for during withdraw.
     *
     * MUST revert if all of assets cannot be withdrawn (due to withdrawal limit being reached, slippage, the owner not
     * having enough shares, etc).
     *
     * Note that some implementations will require pre-requesting to the Vault before a withdrawal may be performed.
     * Those methods should be performed separately.
     */
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);

    /**
     * Maximum amount of Vault shares that can be redeemed from the owner balance in the Vault, through a redeem call.
     *
     * MUST return the maximum amount of shares that could be transferred from owner through redeem and not cause a
     * revert, which MUST NOT be higher than the actual maximum that would be accepted (it should underestimate if
     * necessary).
     *
     * MUST factor in both global and user-specific limits, like if redemption is entirely disabled (even temporarily)
     * it MUST return 0.
     */
    function maxRedeem(address caller) external view returns (uint256 maxShares);

    /**
     * Allows an on-chain or off-chain user to simulate the effects of their redemption at the current block, given
     * current on-chain conditions.
     *
     * MUST return as close to and no more than the exact amount of assets that would be withdrawn in a redeem call in
     * the same transaction. I.e. redeem should return the same or more assets as previewRedeem if called in the same
     * transaction.
     *
     * MUST NOT account for redemption limits like those returned from maxRedeem and should always act as though the
     * redemption would be accepted, regardless if the user has enough shares, etc.
     *
     * MUST be inclusive of withdrawal fees. Integrators should be aware of the existence of withdrawal fees.
     *
     * MUST NOT revert due to vault specific user/global limits. MAY revert due to other conditions that would also
     * cause redeem to revert.
     *
     * Note that any unfavorable discrepancy between convertToAssets and previewRedeem SHOULD be considered slippage in
     * share price or some other type of condition, meaning the depositor will lose assets by redeeming.
     */
    function previewRedeem(uint256 shares) external view returns (uint256 assets);

    /**
     * Burns exactly shares from owner and sends assets of underlying tokens to receiver.
     *
     * MUST emit the Withdraw event.
     *
     * MUST support a redeem flow where the shares are burned from owner directly where owner is msg.sender or
     * msg.sender has ERC-20 approval over the shares of owner. MAY support an additional flow in which the shares are
     * transferred to the Vault contract before the redeem execution, and are accounted for during redeem.
     *
     * MUST revert if all of shares cannot be redeemed (due to withdrawal limit being reached, slippage, the owner not
     * having enough shares, etc).
     *
     * Note that some implementations will require pre-requesting to the Vault before a withdrawal may be performed.
     * Those methods should be performed separately.
     */
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
}
