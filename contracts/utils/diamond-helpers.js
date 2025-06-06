function getSelectors(contract) {
    if (!contract || !contract.interface || typeof contract.interface.getFunction !== 'function') {
      throw new Error("Invalid contract object passed to getSelectors()");
    }
  
    const selectors = [];
    for (const fragment of Object.values(contract.interface.fragments)) {
      if (fragment.type === 'function') {
        const sighash = contract.interface.getFunction(fragment.name).selector;
        selectors.push(sighash);
      }
    }
  
    return selectors;
  }
  
  module.exports = {
    getSelectors,
  };
  
  
// This utility function extracts the function selectors from a contract's interface.
// It can be used to prepare the diamond cut for adding facets to a diamond proxy contract.  