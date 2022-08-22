//SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

//Chainlink Imports
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
// KeeperCompatible.sol imports the functions from both ./KeeperBase.sol and
// ./interfaces/KeeperCompatibleInterface.sol
import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";


contract BullBear is ERC721, ERC721Enumerable, ERC721URIStorage, Ownable, KeeperCompatibleInterface {
    using Counters for Counters.Counter;

    Counters.Counter private _tokenIdCounter;
    uint public interval;
    uint public lastTimeStamp;
    AggregatorV3Interface public priceFeed;
    int256 public currentPrice;

    //IPFS URIs for the dynamic nft graphics/metadata.
    string[] bullUrisIpfs = [
       "https://ipfs.io/ipfs/QmRXyfi3oNZCubDxiVFre3kLZ8XeGt6pQsnAQRZ7akhSNs?filename=gamer_bull.json" ,
       "https://ipfs.io/ipfs/QmRJVFeMrtYS2CUVUM2cHJpBV5aX2xurpnsfZxLTTQbiD3?filename=party_bull.json",
       "https://ipfs.io/ipfs/QmdcURmN1kEEtKgnbkVJJ8hrmsSWHpZvLkRgsKKoiWvW9g?filename=simple_bull.json"
    ];
    
    string[] bearUriIpfs =[
        "https://ipfs.io/ipfs/QmSHyHr3kHKza3YRMfNz5HFatotSvLSa17YHJPzXJow1gU?filename=beanie_bear.json",
        "https://ipfs.io/ipfs/QmTVLyTSuiKGUEmb88BgXG3qNC8YgpHZiFbjHrXKH3QHEu?filename=coolio_bear.json",
        "https://ipfs.io/ipfs/QmbKhBXVWmwrYsTPFYfroR2N7NAekAMxHUVg2CWks7i9qj?filename=simple_bear.json"
    ];

    event TokensUpdated(string marketTrend);

    constructor(uint updateInterval, address _priceFeed) ERC721("Bull&Bear", "BBKT") {
        // Sets the keeper update interval.
        interval = updateInterval;
        lastTimeStamp = block.timestamp;

        //set the price feed address to
        //BTC/USD price feed contract address on Rinkey:
        //or the MockPriceFeed contract
        priceFeed = AggregatorV3Interface(_priceFeed);
        currentPrice = getLatestPrice();
    }

    function safeMint(address to) public onlyOwner {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);

        //Defaults to gamer bull NFT image.
        string memory defaultUri = bullUrisIpfs[0];
        _setTokenURI(tokenId, defaultUri);
    }

    function checkUpkeep(bytes calldata /* checkData */) external view override returns (bool upkeepNeeded, bytes memory /* performData */) {
        upkeepNeeded = (block.timestamp - lastTimeStamp) > interval;
    }

    function performUpkeep(bytes calldata /* performData */) external override {
        if((block.timestamp - lastTimeStamp) > interval) {
            lastTimeStamp = block.timestamp;
            int latestPrice = getLatestPrice();

            if(latestPrice == currentPrice) {
                return;
            }
            if(latestPrice < currentPrice) {
                //bear
                updateAllTokenUris("bear");
            } else {
                //bull
                updateAllTokenUris("bull");
            }

            currentPrice = latestPrice;
        } else {
            // Interval not elepsed. No upkeep.
        }
    }

    function getLatestPrice() public view returns (int256) {
        (,int price,,,) = priceFeed.latestRoundData();
        return price;
    }

    function updateAllTokenUris(string memory trend) internal {
        if(compareStrings("bear", trend)){
            for(uint i=0; i< _tokenIdCounter.current(); i++){
                _setTokenURI(i, bearUriIpfs[i]);
            }
        } else {
            for(uint i=0; i < _tokenIdCounter.current();i++){
                _setTokenURI(i, bullUrisIpfs[i]);
            }
        }
        emit TokensUpdated(trend);
    }

    function setInterval(uint256 newInterval) public onlyOwner {
        interval = newInterval;
    }

    function setPriceFeed(address newFeed) public onlyOwner {
        priceFeed = AggregatorV3Interface(newFeed);
    }

    //Helpers
    function compareStrings(string memory a, string memory b) internal pure returns(bool) {
        return (keccak256(abi.encodePacked(a)) == keccak256(abi.encodePacked(b)));
    }



    //The following functions are overrides required by solidity
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal override(ERC721, ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

     function _burn(uint256 tokenId)
        internal
        override(ERC721, ERC721URIStorage)
    {
        super._burn(tokenId);
    }


    function tokenURI(uint256 tokenId) public view override(ERC721, ERC721URIStorage) returns (string memory) {
        return super.tokenURI(tokenId);
    }

     function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721Enumerable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}