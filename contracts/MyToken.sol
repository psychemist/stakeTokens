// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyToken is ERC20 {
    address private _owner;
    uint256 private constant MAX_SUPPLY = 10 ** 9 * 1e18; // Example: 1 million tokens with 18 decimals

    constructor() ERC20("MyToken", "MTK") {
        _owner = msg.sender;
        _mint(address(this), MAX_SUPPLY);
    }

    modifier onlyOwner() {
        require(msg.sender == _owner);
        _;
    }

    function mintMoreTokens(uint256 _amount) external {
        require(msg.sender == _owner, "Only owner can mint more tokens!");
        _mint(_owner, _amount);
    }

    function getTokens(uint256 _amount) external {
        require(msg.sender != address(0), "Sender cannot be Address Zero!");
        require(_amount > 0, "Cannot transfer 0 tokens!");
        require(IERC20(address(this)).balanceOf(address(this)) >= _amount);

        IERC20(address(this)).transfer(msg.sender, _amount);
    }
}
