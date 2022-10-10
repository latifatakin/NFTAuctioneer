// SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

interface IERC721 {
    function safeTransferFrom(
      address from,
      address to,
      uint256 tokenId
    ) external;

    function transferFrom(
        address,
        address,
        uint
    ) external;
}

contract NFTAuctioneer {
    event Start();
    event Bid(address indexed sender, uint amount);
    event Withdraw(address indexed bidder, uint amount);
    event End(address winner, uint amount);
    event WithdrawNft(address winner, uint amount);


    IERC721 public nft;
    uint public nftId;

    address payable public seller;
    uint public endAt;
    bool public started;
    bool public ended;
    bool public nftWithdrawn;

    address public highestBidder;
    uint public highestBid;
    mapping(address => uint) public bids;

    constructor(
        address _nft,
        uint _nftId,
        uint _startingBid
    ) {
        nft = IERC721(_nft);
        nftId = _nftId;

        seller = payable(msg.sender);
        highestBid = _startingBid;
    }

    function start() external {
        require(!started, "started");
        require(msg.sender == seller, "not seller");
        nft.transferFrom(msg.sender, address(this), nftId);
        started = true;
        endAt = block.timestamp + 7 days;
        emit Start();
    }

    function bid() external payable {
        require(started, "not started");
        require(msg.sender != seller, "You can't bid in your own auction");
        require(block.timestamp < endAt, "ended");
        require(msg.value > highestBid, "value < highest");
        if (highestBidder != address(0)) {
            bids[highestBidder] += highestBid;
        }
        highestBidder = msg.sender;
        highestBid = msg.value;
        emit Bid(msg.sender, msg.value);
    }

    function withdraw() external {
        uint bal = bids[msg.sender];
        require(bal > 0, "No money to withdraw");
        bids[msg.sender] = 0;
        (bool success,) = payable(msg.sender).call{value: bal}("");
        require(success, "Withdrawal failed");
        emit Withdraw(msg.sender, bal);
    }

    function transferHelper(uint _highestBid) internal {
        highestBid = 0;
        (bool success,) = seller.call{value: _highestBid}("");
        require(success, "Payment to seller failed");
        nft.safeTransferFrom(address(this), highestBidder, nftId);
        
    }

    function withdrawNft() external {
        require(started, "not started");
        require(block.timestamp >= endAt, "not ended");
        require(msg.sender == highestBidder, "Only the winner can withdraw the NFT");
        require(!nftWithdrawn, "withdrawn");
        uint bal = highestBid;
        nftWithdrawn = true;
        transferHelper(bal);
        emit WithdrawNft(highestBidder, bal);
    }

    function end() external {
        require(started, "not started");
        require(block.timestamp >= endAt, "There is still time to bid");
        require(!ended, "ended");
        require(msg.sender == seller || msg.sender == highestBidder, "Only the seller or winner can end the auction");
        ended = true;
        if (highestBidder != address(0)) {
            uint bal = highestBid;
            transferHelper(bal);
            emit End(highestBidder, bal);
        } else {
            nft.safeTransferFrom(address(this), seller, nftId);
        }
        
    }

    function endBeforeEndtime() external {
        require(started, "not started");
        require(block.timestamp < endAt, "already reached endAt time");
        require(!ended, "ended");
        require(msg.sender == seller, "only the owner can cancel an auction");
        ended = true;
        if (highestBidder != address(0)) {
            bids[highestBidder] += highestBid;
            highestBidder = address(0);
            highestBid = (0);
        } else {
            nft.safeTransferFrom(address(this), seller, nftId);
        }
        emit End(address(0), 0);
    }
    
}
