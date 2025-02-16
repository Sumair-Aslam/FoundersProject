// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/introspection/ERC165.sol";
import "@openzeppelin/contracts/interfaces/IERC721.sol";
import "./ITB.sol";

contract FoundersMynt is Ownable, ERC20, ERC165 {
    using SafeMath for uint256;

    uint256 constant ONE_BILLION_ETHERS = 1000000000 ether;
    uint8 constant TAX_PERCENTAGE = 5;
    address payable ORIGIN_ADDRESS;
    address public TREASURE_BOX;
    mapping(address => uint256) treasureBoxAssests;
    mapping(address => bool) pairAddress;

    event FoundersMyntBought(
        address buyer,
        uint256 _totalFmynt,
        uint256 _tax,
        uint256 receivedFmynt
    );
    event FoundersMyntSold(
        address seller,
        uint256 _totalFmynt,
        uint256 _tax,
        uint256 soldFmynt
    );
    event EthersFlushed(uint256 _amount);

    constructor(
        address _privateSafe,
        address _teamTokens,
        address _tbg
    ) Ownable(msg.sender) ERC20("Founders Mynt Token", "FMYNT") {
        ORIGIN_ADDRESS = payable(msg.sender);
        _mint(address(this), ONE_BILLION_ETHERS);
        _transfer(
            address(this),
            _privateSafe,
            calculatePercentageOnValue(ONE_BILLION_ETHERS, 10)
        ); //10% private safe
        _transfer(
            address(this),
            _teamTokens,
            calculatePercentageOnValue(ONE_BILLION_ETHERS, 10)
        ); //10% team tokens
        _transfer(
            address(this),
            _tbg,
            calculatePercentageOnValue(ONE_BILLION_ETHERS, 10)
        ); //10% treasure box and gamification
        _transfer(
            address(this),
            ORIGIN_ADDRESS,
            calculatePercentageOnValue(ONE_BILLION_ETHERS, 50)
        ); //50% sellable on DEX
    }

    function transfer(
        address to,
        uint256 value
    ) public virtual override returns (bool) {
        address owner = _msgSender();
        uint256 taxDeduction;

        if (pairAddress[msg.sender] == true || pairAddress[to] == true) {
            taxDeduction = calculatePercentageOnValue(value, TAX_PERCENTAGE);
            _transfer(owner, to, value.sub(taxDeduction));
            _transfer(owner, ORIGIN_ADDRESS, taxDeduction);
            if (pairAddress[msg.sender] == true)
                emit FoundersMyntBought(
                    msg.sender,
                    value,
                    taxDeduction,
                    value.sub(taxDeduction)
                );
            if (pairAddress[to] == true)
                emit FoundersMyntSold(
                    msg.sender,
                    value,
                    taxDeduction,
                    value.sub(taxDeduction)
                );
        } else {
            _transfer(owner, to, value);
        }
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public virtual override returns (bool) {
        address spender = _msgSender();
        uint256 taxDeduction;
        _spendAllowance(from, spender, value);

        if (pairAddress[msg.sender] == true || pairAddress[to] == true) {
            taxDeduction = calculatePercentageOnValue(value, TAX_PERCENTAGE);
            _transfer(from, to, value.sub(taxDeduction));
            _transfer(from, ORIGIN_ADDRESS, taxDeduction);
            if (pairAddress[msg.sender])
                emit FoundersMyntBought(
                    msg.sender,
                    value,
                    taxDeduction,
                    value.sub(taxDeduction)
                );
            if (pairAddress[to] == true)
                emit FoundersMyntSold(
                    msg.sender,
                    value,
                    taxDeduction,
                    value.sub(taxDeduction)
                );
        } else {
            _transfer(from, to, value);
        }
        return true;
    }

    function flushEth() public onlyOwner {
        require(address(this).balance > 0, "Nothing to flush.");
        uint256 ethBalance = address(this).balance;
        ORIGIN_ADDRESS.transfer(address(this).balance);
        emit EthersFlushed(ethBalance);
    }

    function calculatePercentageOnValue(
        uint256 _amount,
        uint256 _percentage
    ) public pure returns (uint256) {
        return (_amount.mul(_percentage)).div(100);
    }

    function addPairAddress(address _pairAddress) public onlyOwner {
        require(_pairAddress != address(0), "Empty address is not allowed.");
        pairAddress[_pairAddress] = true;
    }

    function deletePairAddress(address _pairAddress) public onlyOwner {
        require(_pairAddress != address(0), "Empty address is not allowed.");
        require(
            pairAddress[_pairAddress] == true,
            "This address is not in the taxed accounts list"
        );
        delete pairAddress[_pairAddress];
    }

    function setTreasureBox(address _treasureBox) public onlyOwner {
        require(_treasureBox != address(0), "Invlaid Address.");
        if (TREASURE_BOX == address(0)) {
            TREASURE_BOX = _treasureBox;
            treasureBoxAssests[_treasureBox] = calculatePercentageOnValue(
                ONE_BILLION_ETHERS,
                20
            ); //remaining 20% supply for treasure box reward distribution
        } else {
            treasureBoxAssests[_treasureBox] = treasureBoxAssests[TREASURE_BOX];
            delete treasureBoxAssests[TREASURE_BOX];
            TREASURE_BOX = _treasureBox;
        }
    }

    function increaseTreasureBoxAssests(uint256 _amount) public {
        require(balanceOf(msg.sender) >= _amount, "Insufficient balance.");
        _transfer(msg.sender, address(this), _amount);
        treasureBoxAssests[TREASURE_BOX] += _amount;
    }

    function transferReward(address _to, uint256 _amount) public {
        require(TREASURE_BOX != address(0), "Treasure Box not set.");
        require(
            msg.sender == TREASURE_BOX,
            "Caller is not the treasure box address."
        );
        require(
            treasureBoxAssests[TREASURE_BOX] >= _amount,
            "Treasure box Balance is Low."
        );
        treasureBoxAssests[TREASURE_BOX] = treasureBoxAssests[TREASURE_BOX].sub(
            _amount
        );
        _transfer(address(this), _to, _amount);
    }

    function stakeIntoTreasurePool(
        address _sender,
        uint256 _amount
    ) public returns (bool) {
        require(TREASURE_BOX != address(0), "Treasure Box not set.");
        require(
            msg.sender == TREASURE_BOX,
            "Caller is not the treasure box address."
        );
        treasureBoxAssests[TREASURE_BOX] = treasureBoxAssests[TREASURE_BOX].add(
            _amount
        );
        _transfer(_sender, address(this), _amount);
        return true;
    }

    function checkPairAddress(address _pairAddress) public view returns (bool) {
        return pairAddress[_pairAddress];
    }

    function getTreasureBoxAssests() public view returns (uint256) {
        return treasureBoxAssests[TREASURE_BOX];
    }

    receive() external payable {}

    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override returns (bool) {
        return
            interfaceId == type(ITB).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function getInterfaceId() public pure returns (bytes4) {
        return type(ITB).interfaceId;
    }
}
