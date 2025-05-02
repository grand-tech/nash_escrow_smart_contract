// SPDX-License-Identifier: Apache-2.0

/**
 *Submitted for verification at Etherscan.io on 2020-01-31
 */
pragma solidity 0.8.26;

// import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * USDc Contract
 */
contract USDc is ERC20, Ownable {
    constructor(
        string memory name_,
        string memory symbol_
    ) ERC20(name_, symbol_) {}

    /**
     * Mints tokens to an account.
     * @param account the account to mint tokens to.
     * @param amount the amount of tokens to mint.
     */
    function mint(address account, uint256 amount) external onlyOwner {
        _mint(account, amount);
    }
}
