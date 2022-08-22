//SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

import "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

//Chainlink Imports
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
// KeeperCompatible.sol imports the functions from both ./KeeperBase.sol and
// ./interfaces/KeeperCompatibleInterface.sol
import "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";


contract BullBear is ERC721, ERC721Enumerable, ERC721URIStorage, Ownable, KeeperCompatibleInterface, VRFConsumerBaseV2 {
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

    VRFCoordinatorV2Interface COORDINATOR;
     // Your subscription ID.
    uint64 s_subscriptionId;

    // Goerli coordinator. For other networks,
    // see https://docs.chain.link/docs/vrf-contracts/#configurations
    address vrfCoordinator = 0x2Ca8E0C643bDe4C2E08ab1fA0da3401AdAD7734D;

    // The gas lane to use, which specifies the maximum gas price to bump to.
    // For a list of available gas lanes on each network,
    // see https://docs.chain.link/docs/vrf-contracts/#configurations
    bytes32 keyHash = 0x79d3d8832d904592c0bf9818b621522c988bb8b0c05cdc3b15aea1b6e8db0c15;

    // Depends on the number of requested values that you want sent to the
    // fulfillRandomWords() function. Storing each word costs about 20,000 gas,
    // so 100,000 is a safe default for this example contract. Test and adjust
    // this limit based on the network that you select, the size of the request,
    // and the processing of the callback request in the fulfillRandomWords()
    // function.
    uint32 callbackGasLimit = 100000;

    // The default is 3, but you can set this higher.
    uint16 requestConfirmations = 3;

    // For this example, retrieve 2 random values in one request.
    // Cannot exceed VRFCoordinatorV2.MAX_NUM_WORDS.
    uint32 numWords =  2;

    uint256[] public s_randomWords;
    uint256 public s_requestId;
    address s_owner;

    constructor(uint updateInterval, address _priceFeed, uint64 subscriptionId) ERC721("Bull&Bear", "BBKT") VRFConsumerBaseV2(vrfCoordinator) {
        // Sets the keeper update interval.
        interval = updateInterval;
        lastTimeStamp = block.timestamp;

        //set the price feed address to
        //BTC/USD price feed contract address on Rinkey:
        //or the MockPriceFeed contract
        priceFeed = AggregatorV3Interface(_priceFeed);
        currentPrice = getLatestPrice();

        COORDINATOR = VRFCoordinatorV2Interface(vrfCoordinator);
        s_owner = msg.sender;
        s_subscriptionId = subscriptionId;
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
        (,int price,,,) = priceFeed.latestRoundData(); // example price returned 3034715771688
        return price;
    }

    function updateAllTokenUris(string memory trend) internal {
        //call chainlink random number functionality to select random IPFS item.
        require(s_requestId > 0, "Random function: requestRandomWords() not yet called. Please call atleast one time");
        uint randNumber = getRandomNumber();
        if(compareStrings("bear", trend)){
            for(uint i=0; i< _tokenIdCounter.current(); i++){
                _setTokenURI(i, bearUriIpfs[randNumber]);
            }
        } else {
            for(uint i=0; i < _tokenIdCounter.current();i++){
                _setTokenURI(i, bullUrisIpfs[randNumber]);
            }
        }
        emit TokensUpdated(trend);
    }

    function getRandomNumber() internal returns(uint randNumber){
        randNumber = s_randomWords[0] % 3;
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

     // Assumes the subscription is funded sufficiently.
    function requestRandomWords() external onlyOwner {
        // Will revert if subscription is not set and funded.
        s_requestId = COORDINATOR.requestRandomWords(
        keyHash,
        s_subscriptionId,
        requestConfirmations,
        callbackGasLimit,
        numWords
        );
    }

    function fulfillRandomWords(
        uint256, /* requestId */
        uint256[] memory randomWords
    ) internal override {
        s_randomWords = randomWords;
    }
}
