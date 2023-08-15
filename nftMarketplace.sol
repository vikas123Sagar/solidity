// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract NFTMarketplace is ERC721URIStorage, Ownable {
    using SafeMath for uint256;
    using Counters for Counters.Counter;

    Counters.Counter private tokenIdCounter;

    uint256 private listingFee = 0.05 ether; // Fee to list an artwork
    uint256 private minBidIncrement = 0.01 ether;

    mapping(uint256 => Auction) private tokenIdToAuction;

    struct Auction {
        address seller;
        uint256 startingPrice;
        uint256 highestBid;
        address highestBidder;
        uint256 endTime;
        bool ended;
    }

    event ArtworkListed(uint256 tokenId, uint256 startingPrice);
    event NewBidPlaced(uint256 tokenId, address bidder, uint256 amount);
    event AuctionEnded(uint256 tokenId, address winner, uint256 amount);

    constructor(string memory _name, string memory _symbol) ERC721(_name, _symbol) {}

    function listArtwork(uint256 _tokenId, uint256 _startingPrice, uint256 _duration) external payable {
        require(_exists(_tokenId), "Token does not exist");
        require(msg.value == listingFee, "Listing fee required");
        require(ownerOf(_tokenId) == msg.sender, "Only owner can list");

        tokenIdToAuction[_tokenId] = Auction({
            seller: msg.sender,
            startingPrice: _startingPrice,
            highestBid: 0,
            highestBidder: address(0),
            endTime: block.timestamp + _duration,
            ended: false
        });

        emit ArtworkListed(_tokenId, _startingPrice);
    }

    function placeBid(uint256 _tokenId) external payable {
        Auction storage auction = tokenIdToAuction[_tokenId];
        require(auction.ended == false, "Auction has ended");
        require(block.timestamp < auction.endTime, "Auction has expired");
        require(msg.value > auction.highestBid.add(minBidIncrement), "Bid too low");

        if (auction.highestBidder != address(0)) {
            auction.highestBidder.transfer(auction.highestBid);
        }

        auction.highestBid = msg.value;
        auction.highestBidder = msg.sender;

        emit NewBidPlaced(_tokenId, msg.sender, msg.value);
    }

    function endAuction(uint256 _tokenId) external {
        Auction storage auction = tokenIdToAuction[_tokenId];
        require(auction.ended == false, "Auction has ended");
        require(block.timestamp >= auction.endTime, "Auction not yet ended");

        auction.ended = true;
        _transfer(auction.seller, auction.highestBidder, _tokenId);

        uint256 royalty = auction.highestBid.mul(5).div(100); // 5% royalty to artist
        auction.seller.transfer(auction.highestBid.sub(royalty));
        payable(owner()).transfer(royalty);

        emit AuctionEnded(_tokenId, auction.highestBidder, auction.highestBid);
    }

    function setListingFee(uint256 _fee) external onlyOwner {
        listingFee = _fee;
    }

    function setMinBidIncrement(uint256 _increment) external onlyOwner {
        minBidIncrement = _increment;
    }

    function getAuctionDetails(uint256 _tokenId) external view returns (
        address seller,
        uint256 startingPrice,
        uint256 highestBid,
        address highestBidder,
        uint256 endTime,
        bool ended
    ) {
        Auction storage auction = tokenIdToAuction[_tokenId];
        seller = auction.seller;
        startingPrice = auction.startingPrice;
        highestBid = auction.highestBid;
        highestBidder = auction.highestBidder;
        endTime = auction.endTime;
        ended = auction.ended;
    }
}
