// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract NFTMarketplace is ERC721URIStorage, Ownable {
    using Counters for Counters.Counter;
    using SafeMath for uint256;

    Counters.Counter private tokenIdCounter;

    uint256 private listingFee = 0.05 ether; // Fee to list an artwork
    uint256 private minBidIncrement = 0.01 ether;

    mapping(uint256 => Auction) private tokenIdToAuction;
    mapping(uint256 => address payable) private tokenSellers;

    struct Auction {
        address payable seller; // Change to address payable
        uint256 startingPrice;
        uint256 highestBid;
        address payable highestBidder; // Change to address payable
        uint256 endTime;
        bool ended;
    }

    event ArtworkListed(uint256 tokenId, uint256 startingPrice);
    event NewBidPlaced(uint256 tokenId, address bidder, uint256 amount);
    event AuctionEnded(uint256 tokenId, address winner, uint256 amount);
    event AuctionCancelled(uint256 tokenId, address seller);

    constructor(string memory _name, string memory _symbol)
        ERC721(_name, _symbol)
    {}

    modifier onlySeller(uint256 _tokenId) {
        require(
            ownerOf(_tokenId) == msg.sender,
            "Only seller can call this function"
        );
        _;
    }

    function listArtwork(
        uint256 _tokenId,
        uint256 _startingPrice,
        uint256 _duration
    ) external payable onlySeller(_tokenId) {
        require(_exists(_tokenId), "Token does not exist");
        require(msg.value == listingFee, "Listing fee required");

        tokenIdToAuction[_tokenId] = Auction({
            seller: payable(msg.sender), // Change to address payable
            startingPrice: _startingPrice,
            highestBid: 0,
            highestBidder: payable(address(0)), // Change to address payable
            endTime: block.timestamp + _duration,
            ended: false
        });

        // Store the seller's address for this token
        tokenSellers[_tokenId] = payable(msg.sender); // Change to address payable

        emit ArtworkListed(_tokenId, _startingPrice);
    }

    function placeBid(uint256 _tokenId) external payable {
        Auction storage auction = tokenIdToAuction[_tokenId];
        require(!auction.ended, "Auction has ended");
        require(block.timestamp < auction.endTime, "Auction has expired");
        require(
            msg.value > auction.highestBid.add(minBidIncrement),
            "Bid too low"
        );

        if (auction.highestBidder != address(0)) {
            auction.highestBidder.transfer(auction.highestBid);
        }

        auction.highestBid = msg.value;
        auction.highestBidder = payable(msg.sender); // Change to address payable

        emit NewBidPlaced(_tokenId, msg.sender, msg.value);
    }

    function endAuction(uint256 _tokenId) external {
        Auction storage auction = tokenIdToAuction[_tokenId];
        require(!auction.ended, "Auction has ended");
        require(block.timestamp >= auction.endTime, "Auction not yet ended");
        require(
            msg.sender == auction.seller || msg.sender == owner(),
            "Only seller or owner can end the auction"
        );

        auction.ended = true;
        if (auction.highestBidder != address(0)) {
            _transfer(auction.seller, auction.highestBidder, _tokenId);
            uint256 royalty = auction.highestBid.mul(5).div(100); // 5% royalty to artist
            uint256 sellerProceeds = auction.highestBid.sub(royalty);
            auction.seller.transfer(sellerProceeds);
            payable(owner()).transfer(royalty);
            emit AuctionEnded(
                _tokenId,
                auction.highestBidder,
                auction.highestBid
            );
        } else {
            emit AuctionCancelled(_tokenId, auction.seller);
        }
    }

    function withdraw(uint256 _tokenId) external {
        require(
            tokenIdToAuction[_tokenId].ended &&
                tokenIdToAuction[_tokenId].highestBidder == address(0),
            "Can only withdraw if auction ended with no bids"
        );
        require(
            msg.sender == tokenSellers[_tokenId],
            "Only the seller can withdraw"
        );

        tokenSellers[_tokenId].transfer(listingFee);
    }

    function setListingFee(uint256 _fee) external onlyOwner {
        listingFee = _fee;
    }

    function setMinBidIncrement(uint256 _increment) external onlyOwner {
        minBidIncrement = _increment;
    }

    function getAuctionDetails(uint256 _tokenId)
        external
        view
        returns (
            address seller,
            uint256 startingPrice,
            uint256 highestBid,
            address highestBidder,
            uint256 endTime,
            bool ended
        )
    {
        Auction storage auction = tokenIdToAuction[_tokenId];
        seller = auction.seller;
        startingPrice = auction.startingPrice;
        highestBid = auction.highestBid;
        highestBidder = auction.highestBidder;
        endTime = auction.endTime;
        ended = auction.ended;
    }
}
