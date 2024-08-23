// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/utils/introspection/ERC165Checker.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
// import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
// import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "./IGlobals.sol";
import "./IFMYNT.sol";
import "hardhat/console.sol";
/**
 * @title Myntist Treasure Box
 * @dev A contract for creating and managing treasure boxes with NFTs, Mynt Tokens and ETH.
 */
contract MyntistTreasureBox {
    using SafeMath for uint256;

    /* ============== State Variables ============= */
    // IUniswapV2Pair pairContract;
    // IUniswapV2Router02 router = IUniswapV2Router02(0xD99D1c33F9fC3444f8101754aBC46c52416550D1);
    IERC1155 foundersPass;
    IGlobals private GLOBALS_INSTANCE;
    IFMYNT private immutable foundersMyntContract;
    address payable immutable ORIGIN_ADDRESS;

    uint256 private SILVER_PASS_BASE_PRICE = 1000;
    uint256 private GOLDEN_PASS_BASE_PRICE = SILVER_PASS_BASE_PRICE * 10;
    uint256 private MULTIPLIER = 1000;
    uint256 private constant MIN_TOKEN_DEPOSIT = 0 ether;
    uint256 private constant MAX_TOKENS_DEPOSIT = 100000000 ether;
    uint256 public constant MIN_DURATION = 14;
    uint256 private constant MIN_CREATION_DAYS = 1 days;
    uint256 private constant MAX_CREATION_DAYS = 365 days;
    uint256 totalDistributableAssests;
    using Counters for Counters.Counter;
    Counters.Counter private _boxIds;

    /* ================== Structs ================= */

    struct TreasureBox {
        address creator;
        uint256 depositAmount;
        uint256 totalReward;
        uint256 claimDate;
        uint8 nftId;
        bool distribution;
        bool isBoxClaimed;
        Contributor[] contributors;
    }

    struct Contributor {
        address contributor;
        uint256 depositAmount;
        uint256 totalReward;
        uint256 joinDate;
        uint256 duration;
        bool isRewardClaimed;
    }

    /* ================== Mappings =============== */
    mapping(uint256 => TreasureBox) public treasureBoxes;
    mapping(address => mapping(uint8 => uint256)) stakedFoundersPass;

    /* ================== Events ================= */
    event TreasureBoxCreated(
        address indexed creator,
        uint256 indexed boxId,
        uint256 claimDate,
        uint256 nftId,
        uint256 depositAmount,
        uint256 totalReward
    );

    event RewardClaimed(
        address indexed claimer,
        uint256 indexed boxId,
        uint256 indexed nftId,
        uint256 rewardAmount,
        bool isClaimed
    );

    event ContributionAdded(
        address indexed creator,
        uint256 indexed boxId,
        uint256 claimDate,
        uint256 nftId,
        uint256 depositAmount,
        uint256 totalReward
    );

    event ContributionRewardClaimed(
        address indexed claimer,
        uint256 indexed boxId,
        uint256 indexed nftId,
        uint256 rewardAmount
    );

    event EthersFlushed(uint256 _amount, address owner);

    /* ================== Modifier =============== */
    modifier onlyOwner() {
        require(
            msg.sender == ORIGIN_ADDRESS,
            "Only owner can call this function"
        );

        _;
    }

    /* ============== Constructor ============= */
    /**
     * @dev Constructor sets the global settings for the contract.
     * @param _foundersMyntContractAddress The address of the ERC20 contract for the Founders Mynt tokens.
     * @notice This constructor initializes the Founders Mynt contract address and sets the origin address to the address deploying the contract.
     */
    constructor(
        address _foundersMyntContractAddress,
        /* address _pairContractAddress,*/ address _foundersPassContractAddress
    ) {
        foundersMyntContract = IFMYNT(_foundersMyntContractAddress);
        ORIGIN_ADDRESS = payable(msg.sender);
        // pairContract = IUniswapV2Pair(_pairContractAddress);
        foundersPass = IERC1155(_foundersPassContractAddress);
    }

    /* ================== Functions =============== */

    /**
     * @dev Creates a new treasure box with FMYNT tokens.
     * @notice Requires a future claim date, at least one NFT, and deposit within allowed range.
     * @param _claimDate The future date when the box can be claimed.
     * @param _nftId The id to represent the type of the pass either silver of gold.
     * @param _tokenAmount The amount of FMYNT/MYNT tokens to deposit.
     */
    function createTreasureBox(
        uint256 _claimDate,
        uint8 _nftId,
        uint256 _tokenAmount
    ) public {
        require(_nftId == 1 || _nftId == 2, "Invalid Nft Id");
        require(_tokenAmount >= MIN_TOKEN_DEPOSIT, "Invalid token amount");
        require(_tokenAmount <= MAX_TOKENS_DEPOSIT, "Deposit out of range");
        require(
            _claimDate > block.timestamp,
            "Claim date must be in the future"
        );
        require(
            _claimDate <= block.timestamp + MAX_CREATION_DAYS,
            "Claim date too high"
        );
        require(
            _claimDate >= block.timestamp + MIN_CREATION_DAYS,
            "Claim date too low"
        );
        require(
            foundersPass.balanceOf(msg.sender, _nftId) >
                stakedFoundersPass[msg.sender][_nftId],
            "Insufficent balance of founders pass"
        );
        require(
            foundersMyntContract.balanceOf(msg.sender) >= _tokenAmount,
            "Insufficient tokens in sender's account"
        );

        uint256 rewardTokens = calculateReward(
            _claimDate,
            _nftId,
            _tokenAmount
        );
        require(
            foundersMyntContract.TREASURE_BOX() != address(0),
            "Treasure box address is not set in FMYNT"
        );
        require(
            rewardTokens <=
                (
                    (foundersMyntContract.getTreasureBoxAssests()).add(
                        _tokenAmount
                    )
                ).sub(totalDistributableAssests),
            "Cannot create, treasure box supply cap reached"
        );
        require(
            foundersMyntContract.stakeIntoTreasurePool(
                msg.sender,
                _tokenAmount
            ),
            "Unable to stake tokens"
        );
        totalDistributableAssests += rewardTokens;
        stakedFoundersPass[msg.sender][_nftId]++;
        _boxIds.increment();

        // Saves info
        TreasureBox storage newBox = treasureBoxes[_boxIds.current()];
        newBox.creator = msg.sender;
        newBox.totalReward = rewardTokens;
        newBox.nftId = _nftId;
        newBox.depositAmount = _tokenAmount;
        newBox.claimDate = _claimDate;

        emit TreasureBoxCreated(
            msg.sender,
            _boxIds.current(),
            _nftId,
            _claimDate,
            _tokenAmount,
            rewardTokens
        );
    }

    /**
     * @dev Calculates the reward tokens for a given FMYNT deposit for a future treasure box.
     * @notice Calculation based on the claim date and number of NFTs.
     * @param _claimDate The future date when the box can be claimed.
     * @param _depositTokenAmount The deposit amount in token for which to calculate the reward tokens.
     * @return uint256 representing the calculated reward tokens.
     */
    function calculateReward(
        uint256 _claimDate,
        uint256 _nftId,
        uint256 _depositTokenAmount
    ) public view returns (uint256) {
        uint256 basePrice;
        uint256 duration = (_claimDate.sub(block.timestamp)).div(86400); //86400 = number of seconds in one day.
        basePrice = (20000000000000000000000 / MULTIPLIER).add(
            _nftId == 1 ? SILVER_PASS_BASE_PRICE : 
            _nftId == 2 ? GOLDEN_PASS_BASE_PRICE :
            0
        );
        console.log("Duration: ", duration);

        // Reward = (duration / minDuration) * ((basePrice + (deposit * 0.3)) / minDuration) + desposit
        return _getReward(duration, basePrice, _depositTokenAmount);
    }

    function _getReward(uint256 duration, uint256 basePrice, uint256 depositTokenAmount) public pure returns (uint256){
        return
            (
                duration.div(MIN_DURATION).mul(
                    (
                        basePrice.add(
                            calculatePercentage(depositTokenAmount, 30)
                        )
                    ).div(MIN_DURATION)
                )
            ).add(depositTokenAmount);
    }

    function calculatePercentage(
        uint256 _amount,
        uint256 _percentage
    ) public pure returns (uint256) {
        return (_amount.mul(_percentage)).div(100);
    }

    /**
     * @dev Allows the owner of an NFT within a specific treasure box to claim their share of the rewards.
     * @notice The treasure box must exist, and the NFT must be part of it. Rewards are claimed once.
     * @param _boxId The ID of the treasure box from which to claim rewards.
     */
    function claimTreasureBox(uint256 _boxId) public {
        require(_boxId > 0 && _boxId <= _boxIds.current(), "Invalid box ID");
        TreasureBox storage box = treasureBoxes[_boxId];
        // require(block.timestamp >= box.claimDate, "Too early to claim");
        require(box.isBoxClaimed == false, "Box already claimed");
        require(
            foundersMyntContract.getTreasureBoxAssests() > 0,
            "Cannot claim, treasure box supply cap reached"
        );
        foundersMyntContract.transferReward(
            ORIGIN_ADDRESS,
            calculatePercentage(box.totalReward, 5)
        );
        foundersMyntContract.transferReward(
            msg.sender,
            calculatePercentage(box.totalReward, 95)
        );
        totalDistributableAssests -= box.totalReward;
        stakedFoundersPass[msg.sender][box.nftId]--;
        box.isBoxClaimed = true;

        emit RewardClaimed(
            msg.sender,
            _boxId,
            box.nftId,
            box.totalReward,
            box.isBoxClaimed
        );
    }

    /**
     * @dev Allows contributing to a treasure box using FMYNT contract _depositTokens, increasing the total reward amount available for rewards.
     * @notice The treasure box must exist and not have reached its claim date.
     * @param _boxId The ID of the treasure box to fund.
     * @param _depositTokens The amount of tokens to add to the treasure box's rewards.
     */
    function contributeToTreasureBox(
        uint256 _boxId,
        uint256 _depositTokens
    ) public {
        require(_boxId > 0 && _boxId <= _boxIds.current(), "Invalid Box ID");
        TreasureBox storage treasureBox = treasureBoxes[_boxId];
        uint256 _claimDate = treasureBox.claimDate;
        require(
            block.timestamp < treasureBox.claimDate,
            "Cannot Fund After Maturity"
        );
        require(_depositTokens > 0, "Insufficient FMYNT Tokens");
        require(
            _claimDate >= block.timestamp + MIN_DURATION,
            "Cannot contribute now"
        );
        require(
            foundersMyntContract.balanceOf(msg.sender) >= _depositTokens,
            "Insufficient tokens in sender's account"
        );
        require(
            foundersMyntContract.stakeIntoTreasurePool(
                msg.sender,
                _depositTokens
            ),
            "Unable to stake tokens"
        );

        uint256 rewardTokens = calculateContributionReward(
            _claimDate,
            treasureBox,
            _depositTokens
        );
        Contributor memory contributor;
        contributor.contributor = msg.sender;
        contributor.depositAmount = _depositTokens;
        contributor.totalReward = rewardTokens;
        contributor.joinDate = block.timestamp;
        contributor.duration = (_claimDate.sub(block.timestamp)).div(86400);

        treasureBox.contributors.push(contributor);
        totalDistributableAssests += rewardTokens;

        emit ContributionAdded(
            msg.sender,
            _boxIds.current(),
            treasureBox.nftId,
            _claimDate,
            _depositTokens,
            rewardTokens
        );
    }

    function calculateContributionReward(
        uint256 _claimDate,
        TreasureBox memory treasureBox,
        uint256 _depositTokenAmount
    ) public view returns (uint256) {
        uint256 basePrice;
        uint256 duration = (_claimDate.sub(block.timestamp)).div(86400); //86400 = number of seconds in one day.
        if (treasureBox.nftId == 1)
            basePrice = (20000000000000000000000 / MULTIPLIER).add(
                SILVER_PASS_BASE_PRICE / 2
            );
        else
            basePrice = (20000000000000000000000 / MULTIPLIER).add(
                GOLDEN_PASS_BASE_PRICE / 2
            );
        return _getReward(duration, basePrice, _depositTokenAmount);
    }

    function claimTreasureBoxContributionReward(uint256 _boxId) public {
        require(_boxId > 0 && _boxId <= _boxIds.current(), "Invalid box ID");
        TreasureBox storage box = treasureBoxes[_boxId];
        // require(block.timestamp >= box.claimDate, "Too early to claim");
        require(
            foundersMyntContract.getTreasureBoxAssests() > 0,
            "Cannot claim, treasure box supply cap reached"
        );

        bool isFound = false;
        uint256 index;
        for (index = 0; index < box.contributors.length; index++) {
            if (box.contributors[index].contributor == msg.sender) {
                isFound = true;
                break;
            }
        }

        require(isFound == true, "Caller is not the contributor");
        require(
            box.contributors[index].isRewardClaimed == false,
            "Reward already claimed"
        );
        uint256 totalReward = box.contributors[index].totalReward;
        foundersMyntContract.transferReward(
            msg.sender,
            calculatePercentage(totalReward, 70)
        );
        foundersMyntContract.transferReward(
            box.creator,
            calculatePercentage(totalReward, 25)
        );
        foundersMyntContract.transferReward(
            ORIGIN_ADDRESS,
            calculatePercentage(totalReward, 5)
        );
        totalDistributableAssests -= totalReward;
        box.contributors[index].isRewardClaimed = true;

        emit ContributionRewardClaimed(
            msg.sender,
            _boxId,
            box.nftId,
            totalReward
        );
    }

    function setSilverBaseValue(uint256 _silverBaseValue) public {
        SILVER_PASS_BASE_PRICE = _silverBaseValue;
    }

    function setMultiplier(uint256 _multiplier) public {
        MULTIPLIER = _multiplier;
    }

    /**
     * @dev Flushes the contract's balance to the owner's address.
     * @notice Only the contract owner can call this function.
     */
    function flushEthToOwner() public onlyOwner {
        uint256 eth = address(this).balance;
        require(eth > 0, "MYNT: No ETH to flush");
        ORIGIN_ADDRESS.transfer(address(this).balance);
        emit EthersFlushed(eth, ORIGIN_ADDRESS);
    }
}
