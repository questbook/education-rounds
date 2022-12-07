// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;
import "@openzeppelin/contracts/access/Ownable.sol";


contract EducationRounds is Ownable{

    address payable DAOADDRESS;

    constructor() {
        // todo : change to upgradable contract
        DAOADDRESS = payable (msg.sender);
    }

    function changeDaoAddress(address daoAddress) public onlyOwner {
        DAOADDRESS = payable(daoAddress);
    }

    struct StringNumberTuple {
        string str;
        uint num;
    }

    struct Round {
        mapping(string => uint) commitVotes;
        mapping(string => mapping(string => uint) ) contentVotes;
        mapping (string => StringNumberTuple) winningContent;
        mapping(string => mapping(string => bool) ) isContent;
        uint commitVoteCount;
        mapping (string => uint) contentVoteCount;
        uint start;
        uint funding;
    }

    mapping(string => mapping (uint => Round)) rounds;
    mapping(string => uint) currentRoundNumber;

    mapping(string => mapping(address => uint)) commitVoteCount;
    mapping(string => mapping(address => uint)) contentVoteCount;
    mapping(string => mapping(uint => mapping(string => bool))) claimed;

    mapping(string => address) originalSubmitter;

    event VotedOnCommit(string repo, uint roundNumber, string commitId);
    function voteOnCommit(string memory repo, string memory commitId ) public {
        //todo : using credentials protocol to prove voter is a contributor to `repo`
        require(commitVoteCount[repo][msg.sender] <= 20);
        commitVoteCount[repo][msg.sender] += 1;
        rounds[repo][currentRoundNumber[repo]].commitVotes[commitId] += 1;
        rounds[repo][currentRoundNumber[repo]].commitVoteCount += 1;
        emit VotedOnCommit(repo, currentRoundNumber[repo], commitId);
    }

    event VotedOnContent(string repo, uint roundNumber, string commitId, string contentId);
    function voteOnContent(string memory repo, string memory commitId, string memory contentId) public {
        //todo : using credentials protocol to prove voter is a contributor to `repo`
        require(contentVoteCount[repo][msg.sender]<=20);
        require(rounds[repo][currentRoundNumber[repo]].commitVoteCount > 0);
        rounds[repo][currentRoundNumber[repo]].contentVotes[commitId][contentId] += 1;
        rounds[repo][currentRoundNumber[repo]].contentVoteCount[commitId] += 1;
        emit VotedOnContent(repo, currentRoundNumber[repo], commitId, contentId);
        if(rounds[repo][currentRoundNumber[repo]].winningContent[commitId].num < rounds[repo][currentRoundNumber[repo]].contentVotes[commitId][contentId]) {
            rounds[repo][currentRoundNumber[repo]].winningContent[commitId].num = rounds[repo][currentRoundNumber[repo]].contentVotes[commitId][contentId];
            rounds[repo][currentRoundNumber[repo]].winningContent[commitId].str = contentId;
        }
    }

    event ContentSubmitted(string repo, uint RoundNumber, string commitId, string contentId);
    function submitContent(string memory repo, string memory commitId, string memory contentId) public {
        require(rounds[repo][currentRoundNumber[repo]].contentVotes[commitId][contentId] == 0);
        rounds[repo][currentRoundNumber[repo]].isContent[commitId][contentId] = true;
        if(originalSubmitter[contentId] == address(0)){ 
            originalSubmitter[contentId] = msg.sender; // can be front run
            // also use zkproof of prehash knowledge here.
        }
        emit ContentSubmitted(repo, currentRoundNumber[repo], commitId, contentId);
    }

    function fund(string memory repo) public payable  {
        rounds[repo][currentRoundNumber[repo]].funding += msg.value;
    }

    bool reentrancyLock = false;

    function nextRound(string memory repo) public {
        //require(rounds[repo][currentRoundNumber[repo]].start < block.timestamp - 30 days);
        require(!reentrancyLock);
        reentrancyLock = true;
        DAOADDRESS.call{ value : rounds[repo][currentRoundNumber[repo]].funding * 2/10}("");
        currentRoundNumber[repo] += 1;
        reentrancyLock = false;
    }

    function claim(string memory repo, uint roundNumber, string memory commitId, string memory contentId, address to) public {
        require(!claimed[repo][roundNumber][commitId]);
        require(!reentrancyLock);
        reentrancyLock = true;
        uint amount = rounds[repo][roundNumber].funding * ( rounds[repo][roundNumber].commitVotes[commitId] * rounds[repo][roundNumber].contentVotes[commitId][contentId] *8)/(10 * rounds[repo][roundNumber].commitVoteCount * rounds[repo][roundNumber].contentVoteCount[commitId]);
        payable(to).call{value: amount}("");
        claimed[repo][roundNumber][commitId] = true;
        reentrancyLock = false;
    }

    function getCurrentRound(string memory repo) public view returns(uint){
        return currentRoundNumber[repo];
    }

    function getCommitVotes(string memory repo, uint roundNumber, string memory commitId) public view returns(uint) {
        return rounds[repo][roundNumber].commitVotes[commitId];
    }

    function getTopContent(string memory repo, uint roundNumber, string memory commitId) public view returns(string memory) {
        return rounds[repo][roundNumber].winningContent[commitId].str;
    }

    function getFunding(string memory repo, uint roundNumber) public view returns(uint){
        return rounds[repo][roundNumber].funding;
    }

    event RepoAdded(string repo);
    function addRepo(string memory repo) public {
        emit RepoAdded(repo);
    }

    
}