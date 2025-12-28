// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Distriba Token (DSRX)
 * @notice ERC20 token minted only through protocol rules.
 *
 * IMPORTANT:
 * - This contract is intentionally simple.
 * - Minting and burning are restricted to a single controller (VestingVault).
 * - No owner functions for arbitrary minting.
 */
contract DSRX {
    /*//////////////////////////////////////////////////////////////
                                METADATA
    //////////////////////////////////////////////////////////////*/

    string public constant name = "Distriba";
    string public constant symbol = "DSRX";
    uint8  public constant decimals = 18;

    /*//////////////////////////////////////////////////////////////
                             ERC20 STORAGE
    //////////////////////////////////////////////////////////////*/

    uint256 public totalSupply;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    /*//////////////////////////////////////////////////////////////
                           ACCESS CONTROL
    //////////////////////////////////////////////////////////////*/

    /// @notice The only contract allowed to mint/burn DSRX.
    address public immutable controller;

    /*//////////////////////////////////////////////////////////////
                                EVENTS
    //////////////////////////////////////////////////////////////*/

    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);

    /*//////////////////////////////////////////////////////////////
                              CONSTRUCTOR
    //////////////////////////////////////////////////////////////*/

    constructor(address controller_) {
        require(controller_ != address(0), "controller=0");
        controller = controller_;
    }

    /*//////////////////////////////////////////////////////////////
                           ERC20 LOGIC
    //////////////////////////////////////////////////////////////*/

    function approve(address spender, uint256 amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external returns (bool) {
        uint256 allowed = allowance[from][msg.sender];
        require(allowed >= amount, "allowance");

        if (allowed != type(uint256).max) {
            allowance[from][msg.sender] = allowed - amount;
        }

        _transfer(from, to, amount);
        return true;
    }

    function _transfer(address from, address to, uint256 amount) internal {
        require(to != address(0), "to=0");
        require(balanceOf[from] >= amount, "balance");

        unchecked {
            balanceOf[from] -= amount;
            balanceOf[to] += amount;
        }

        emit Transfer(from, to, amount);
    }

    /*//////////////////////////////////////////////////////////////
                       MINT / BURN (RESTRICTED)
    //////////////////////////////////////////////////////////////*/

    /// @notice Mint new DSRX (only VestingVault).
    function mint(address to, uint256 amount) external {
        require(msg.sender == controller, "not controller");
        require(to != address(0), "to=0");

        totalSupply += amount;
        balanceOf[to] += amount;

        emit Transfer(address(0), to, amount);
    }

    /// @notice Burn DSRX (used when converting or vesting logic).
    function burn(address from, uint256 amount) external {
        require(msg.sender == controller, "not controller");
        require(balanceOf[from] >= amount, "balance");

        unchecked {
            balanceOf[from] -= amount;
            totalSupply -= amount;
        }

        emit Transfer(from, address(0), amount);
    }
}
