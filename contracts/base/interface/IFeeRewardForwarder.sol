pragma solidity ^0.5.16;


interface IFeeRewardForwarder {

    /**
     * @param _token            the token that will be compounded or sold into FARM
     * @param _feeAmount        the amount of `_token` that will be sold into FARM
     * @param _buybackTokens    the output tokens that `_buyBackAmounts` should be outputted to
     * @param _buybackAmounts   the amounts of `_token` that will be bought into more `_buybackTokens` token
     * @return The amounts that were purchased of _buybackTokens
     */
    function notifyFeeAndBuybackAmounts(
        address _token,
        uint256 _feeAmount,
        address[] calldata _buybackTokens,
        uint256[] calldata _buybackAmounts
    ) external returns (uint[] memory amounts);

    function profitSharingPool() external view returns (address);
}
