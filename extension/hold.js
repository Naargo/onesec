// Shows which website is waiting, as plain text.
const site = decodeURIComponent(location.hash.slice(1));
document.getElementById('site').textContent = site ? `${site} is waiting for OneSec` : 'Waiting for OneSec';
document.title = site ? `OneSec: ${site}` : 'OneSec';
