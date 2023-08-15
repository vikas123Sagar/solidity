# NFT Marketplace Smart Contract

This is a decentralized digital art marketplace built on the Ethereum blockchain using Solidity. It enables artists to list their digital artworks as NFTs for auction, allowing users to place bids and purchase these NFTs.

## Features

- Artists can list their artworks for auction with a starting price and a specified duration.
- Users can place bids on the listed artworks.
- Bidders can win an artwork at the end of the auction.
- The contract ensures a minimum bid increment and manages the highest bidder and amount.
- The contract also enforces a 5% royalty fee for artists on secondary sales.
- The marketplace owner receives the royalty and the listing fees.

## Usage

1. Deploy the smart contract on the Ethereum blockchain.
2. As the contract owner, set the listing fee and minimum bid increment using the respective functions.
3. Artists can mint their artworks as NFTs using the ERC721 `mint` function.
4. Artists can then list their NFTs for auction using the `listArtwork` function, specifying the tokenId, starting price, and auction duration.
5. Users can place bids on listed artworks using the `placeBid` function, ensuring the bid is higher than the current highest bid plus the minimum bid increment.
6. At the end of the auction, the artist receives the final bid minus the royalty, and the contract owner receives the royalty.
7. The `endAuction` function is used by the contract owner to finalize the auction, transferring the NFT to the highest bidder.

## Contract Address

The deployed contract address on the Ethereum mainnet: [Contract Address]

## Important Note

- This is a simplified example and should not be used in production without thorough testing and security audits.
- Ensure that you understand the code and its implications before deploying it to the blockchain.
- The contract requires the OpenZeppelin ERC721 and Ownable libraries.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

