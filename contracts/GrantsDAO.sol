pragma solidity 0.5.13;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract GrantsDAO {

  uint256 public constant SUBMISSION_PHASE = 2 days;
  uint256 public constant VOTING_PHASE = 9 days; // for 7 days after the submission phase

  struct Proposal {
    address receiver;
    uint256 amount;
    uint256 createdAt;
    uint256 votes;
  }

  uint256 public counter = 1;
  uint256 public members;
  uint256 public toPass;
  IERC20 public SNX;

  mapping(uint256 => Proposal) public proposals;
  mapping(address => bool) public teamMembers;
  mapping(address => bool) public communityMembers;

  event NewProposal(address receiver, uint256 amount, uint256 proposalNumber);
  event VoteProposal(address member);
  event ExecuteProposal(address receiver, uint256 amount);

  constructor(
    address _snx,
    address[] memory _teamMembers,
    address[] memory _communityMembers,
    uint256 _toPass
  ) public {
    for (uint i = 0; i < _teamMembers.length; i++) {
      teamMembers[_teamMembers[i]] = true;
      members++;
    }
    for (uint i = 0; i < _communityMembers.length; i++) {
      communityMembers[_communityMembers[i]] = true;
      members++;
    }

    require(_toPass <= members, "Not enough members to pass votes");
    toPass = _toPass;
    SNX = IERC20(_snx);
  }

  function createProposal(
    address _receiver,
    uint256 _amount
  ) external onlyProposer() {
    require(_amount > 0, "Amount must be greater than 0");
    require(_receiver != address(0), "Receiver cannot be zero address");
    require(_amount <= SNX.balanceOf(address(this)), "Invalid funds on DAO");
    proposals[counter] = Proposal(_receiver, _amount, block.timestamp, 0);
    emit NewProposal(_receiver, _amount, counter);
    counter++;
  }

  function voteProposal(uint256 _proposal) external onlyProposer() isValidProposal(_proposal) {
    proposals[_proposal].votes++;
    if (proposals[_proposal].votes == toPass) {
      executeProposal(_proposal);
    }
    emit VoteProposal(msg.sender);
  }

  function executeProposal(uint256 _proposal) private {
    Proposal memory proposal = proposals[_proposal];
    delete proposals[_proposal];
    assert(SNX.transfer(proposal.receiver, proposal.amount));
    emit ExecuteProposal(proposal.receiver, proposal.amount);
  }

  modifier isValidProposal(uint256 _proposal) {
    uint256 createdAt = proposals[_proposal].createdAt;
    require(createdAt <= block.timestamp - SUBMISSION_PHASE, "Proposal in submission phase");
    require(block.timestamp <= createdAt + VOTING_PHASE, "Proposal not in voting phase");
    _;
  }

  modifier onlyProposer() {
    require(
      teamMembers[msg.sender] ||
      communityMembers[msg.sender],
      "Not proposer"
    );
    _;
  }
}
