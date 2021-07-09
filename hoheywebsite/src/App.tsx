import logo from './logo.svg';
import { Message, Button } from "semantic-ui-react";
import 'semantic-ui-css/semantic.min.css';
import './App.css';

function App() {
  const account = "test"
  return (
    <div className="App">
      <div className="App-header">
        <h1>Testing</h1>
        <div>Account: {account}</div>
        
        <Message warning>Metamask is not connected</Message>
        <Button color="blue">Connect to Metamask</Button>
      </div>
    </div>
  );
}

export default App;
