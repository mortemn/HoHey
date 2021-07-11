import React from "react";
import Web3 from 'web3';
import { Message, Button } from "semantic-ui-react";
import 'semantic-ui-css/semantic.min.css';
import detectEthereumProvider from '@metamask/detect-provider';
import './App.css';

function App() {
  const loadMetamask = () => {
    ethereum.request({ method: 'eth_requestAccounts' });
  }
  return (
    <div className="App">
      <div className="App-header">
        <h1>Testing</h1>
        
        <Message warning>Metamask is not connected</Message>
        <button color="green"
          onClick={() => loadMetamask()}
        >Connect to Metamask</button>
      </div>
    </div>
  );
}

export default App;
