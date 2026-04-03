#!/bin/bash
set -e

# ── System setup ──────────────────────────────────────────
curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
dnf install -y nodejs mysql
node --version
npm --version

# ── App directory ─────────────────────────────────────────
mkdir -p /opt/webapp
cd /opt/webapp

# ── package.json ─────────────────────────────────────────
cat > package.json <<'PKG'
{
  "name": "items-app",
  "version": "1.0.0",
  "main": "server.js",
  "dependencies": {
    "express": "^4.18.2",
    "mysql2": "^3.6.0"
  }
}
PKG

npm install

# ── server.js (Express + MySQL) ───────────────────────────
# ── server.js (Express + MySQL) ───────────────────────────
cat > server.js <<'APP'
const express = require('express');
const mysql = require('mysql2/promise');

const requiredEnv = ['DB_HOST','DB_USER','DB_PASSWORD','DB_NAME'];
for (const v of requiredEnv) {
  if (!process.env[v]) {
    console.error('Missing required environment variable: ' + v);
    process.exit(1);
  }
}

const app = express();
app.use(express.json());
app.use(express.urlencoded({ extended: true }));

const basePool = mysql.createPool({
  host: process.env.DB_HOST,
  port: parseInt(process.env.DB_PORT || '3306'),
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  waitForConnections: true,
  connectionLimit: 5
});

let pool;

async function initDB() {
  const conn = await basePool.getConnection();
  await conn.query('CREATE DATABASE IF NOT EXISTS `' + process.env.DB_NAME + '`');
  await conn.query('USE `' + process.env.DB_NAME + '`');
  await conn.query('CREATE TABLE IF NOT EXISTS items (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(255) NOT NULL, description TEXT, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP)');
  conn.release();
  pool = mysql.createPool({
    host: process.env.DB_HOST,
    port: parseInt(process.env.DB_PORT || '3306'),
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    waitForConnections: true,
    connectionLimit: 10
  });
  console.log('DB initialised');
}

app.get('/health', (req, res) => res.json({ status: 'ok' }));

app.get('/items', async (req, res) => {
  const [rows] = await pool.query('SELECT * FROM items ORDER BY created_at DESC');
  res.json(rows);
});

app.post('/items', async (req, res) => {
  const { name, description } = req.body;
  if (!name) return res.status(400).json({ error: 'name is required' });
  const [result] = await pool.query('INSERT INTO items (name, description) VALUES (?, ?)', [name, description || '']);
  const [rows] = await pool.query('SELECT * FROM items WHERE id = ?', [result.insertId]);
  res.status(201).json(rows[0]);
});

app.delete('/items/:id', async (req, res) => {
  await pool.query('DELETE FROM items WHERE id = ?', [req.params.id]);
  res.json({ deleted: true });
});

app.get('/', (req, res) => {
  const hostname = require('os').hostname();
  res.send('<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Items Manager</title>'
    + '<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600&display=swap" rel="stylesheet">'
    + '<style>'
    + '*{box-sizing:border-box;margin:0;padding:0}'
    + 'body{font-family:"Inter",sans-serif;background:#f0f2f5;color:#1a1a2e;min-height:100vh}'
    + 'header{background:#1a1a2e;color:white;padding:16px 32px;display:flex;align-items:center;justify-content:space-between;box-shadow:0 2px 8px rgba(0,0,0,0.2)}'
    + 'header h1{font-size:20px;font-weight:600;letter-spacing:-0.3px}'
    + 'header span{font-size:12px;color:#8892b0;background:#0d0d1a;padding:4px 10px;border-radius:20px}'
    + '.container{max-width:900px;margin:36px auto;padding:0 20px;display:grid;grid-template-columns:320px 1fr;gap:24px;align-items:start}'
    + '.card{background:white;border-radius:12px;box-shadow:0 1px 4px rgba(0,0,0,0.08);overflow:hidden}'
    + '.card-header{padding:18px 24px;border-bottom:1px solid #f0f0f0}'
    + '.card-header h2{font-size:15px;font-weight:600;color:#1a1a2e}'
    + '.card-header p{font-size:12px;color:#8892b0;margin-top:2px}'
    + '.card-body{padding:20px 24px}'
    + 'label{display:block;font-size:12px;font-weight:500;color:#444;margin-bottom:5px;letter-spacing:0.02em}'
    + 'input[type=text],textarea{width:100%;padding:9px 12px;border:1.5px solid #e2e8f0;border-radius:8px;font-family:inherit;font-size:13px;color:#1a1a2e;outline:none;transition:border 0.2s;resize:none}'
    + 'input[type=text]:focus,textarea:focus{border-color:#4f46e5}'
    + 'textarea{height:80px}'
    + '.field{margin-bottom:14px}'
    + 'button.btn-primary{width:100%;padding:10px;background:#4f46e5;color:white;border:none;border-radius:8px;font-family:inherit;font-size:13px;font-weight:600;cursor:pointer;transition:background 0.2s,transform 0.1s}'
    + 'button.btn-primary:hover{background:#4338ca}'
    + 'button.btn-primary:active{transform:scale(0.98)}'
    + '.toast{margin-top:12px;padding:9px 12px;border-radius:8px;font-size:12px;display:none}'
    + '.toast.success{display:block;background:#f0fdf4;color:#16a34a;border:1px solid #bbf7d0}'
    + '.toast.error{display:block;background:#fef2f2;color:#dc2626;border:1px solid #fecaca}'
    + '.items-list{display:flex;flex-direction:column;gap:10px}'
    + '.item-card{background:white;border:1.5px solid #f0f0f0;border-radius:10px;padding:14px 16px;display:flex;align-items:flex-start;justify-content:space-between;gap:12px;transition:border-color 0.2s,box-shadow 0.2s}'
    + '.item-card:hover{border-color:#e0e0f0;box-shadow:0 2px 8px rgba(79,70,229,0.07)}'
    + '.item-info{flex:1;min-width:0}'
    + '.item-name{font-size:14px;font-weight:600;color:#1a1a2e;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}'
    + '.item-desc{font-size:12px;color:#64748b;margin-top:3px;line-height:1.5}'
    + '.item-meta{font-size:11px;color:#aab0bc;margin-top:6px}'
    + '.btn-delete{background:none;border:1.5px solid #fee2e2;color:#dc2626;border-radius:7px;padding:5px 10px;font-size:12px;font-weight:500;cursor:pointer;white-space:nowrap;transition:background 0.2s,border-color 0.2s}'
    + '.btn-delete:hover{background:#fef2f2;border-color:#fca5a5}'
    + '.empty{text-align:center;padding:48px 20px;color:#aab0bc}'
    + '.empty p{font-size:13px}'
    + '.badge{display:inline-block;background:#ede9fe;color:#4f46e5;font-size:11px;font-weight:600;padding:2px 8px;border-radius:20px;margin-left:8px}'
    + '.skeleton{background:linear-gradient(90deg,#f0f0f0 25%,#e0e0e0 50%,#f0f0f0 75%);background-size:200% 100%;animation:shimmer 1.2s infinite;border-radius:10px;height:68px;margin-bottom:10px}'
    + '@keyframes shimmer{0%%{background-position:200%% 0}100%%{background-position:-200%% 0}}'
    + '@media(max-width:680px){.container{grid-template-columns:1fr}}'
    + '</style></head><body>'
    + '<header><h1>Items Manager</h1><span>' + hostname + '</span></header>'
    + '<div class="container">'
    + '<div class="card"><div class="card-header"><h2>Add New Item</h2><p>Fill in the details below</p></div>'
    + '<div class="card-body"><form id="itemForm">'
    + '<div class="field"><label>Name *</label><input type="text" id="name" placeholder="Enter item name..." required></div>'
    + '<div class="field"><label>Description</label><textarea id="description" placeholder="Enter description..."></textarea></div>'
    + '<button type="submit" class="btn-primary" id="submitBtn">Add Item</button>'
    + '</form><div class="toast" id="toast"></div></div></div>'
    + '<div><div class="card-header" style="background:white;border-radius:12px 12px 0 0;border-bottom:1px solid #f0f0f0;padding:18px 24px">'
    + '<h2 style="font-size:15px;font-weight:600">All Items <span class="badge" id="count">0</span></h2></div>'
    + '<div style="padding:16px 0" id="items-wrapper">'
    + '<div class="skeleton"></div><div class="skeleton"></div><div class="skeleton"></div>'
    + '</div></div></div>'
    + '<script>'
    + 'var items=[];'
    + 'function fmtDate(ts){var d=new Date(ts);return d.toLocaleDateString("en-US",{month:"short",day:"numeric",year:"numeric"})+" "+d.toLocaleTimeString("en-US",{hour:"2-digit",minute:"2-digit"});}'
    + 'function esc(s){return String(s).replace(/&/g,"&amp;").replace(/</g,"&lt;").replace(/>/g,"&gt;");}'
    + 'function render(){'
    + '  document.getElementById("count").textContent=items.length;'
    + '  var w=document.getElementById("items-wrapper");'
    + '  if(items.length===0){w.innerHTML="<div class=\'empty\'><p>No items yet. Add your first one.</p></div>";return;}'
    + '  var html="<div class=\'items-list\'>";'
    + '  items.forEach(function(item){'
    + '    html+="<div class=\'item-card\'><div class=\'item-info\'><div class=\'item-name\'>"+esc(item.name)+"</div>"'
    + '      +(item.description?"<div class=\'item-desc\'>"+esc(item.description)+"</div>":"")'
    + '      +"<div class=\'item-meta\'>#"+item.id+" &middot; "+fmtDate(item.created_at)+"</div></div>"'
    + '      +"<button class=\'btn-delete\' onclick=\'del("+item.id+")\'>Delete</button></div>";'
    + '  });'
    + '  html+="</div>";w.innerHTML=html;'
    + '}'
    + 'function showToast(msg,type){var t=document.getElementById("toast");t.textContent=msg;t.className="toast "+type;clearTimeout(t._t);t._t=setTimeout(function(){t.className="toast";},3000);}'
    + 'async function loadItems(){try{var res=await fetch("/items");items=await res.json();render();}catch(e){document.getElementById("items-wrapper").innerHTML="<div class=\'empty\'><p>Failed to load items.</p></div>";}}'
    + 'document.getElementById("itemForm").addEventListener("submit",async function(e){'
    + '  e.preventDefault();'
    + '  var btn=document.getElementById("submitBtn");'
    + '  var name=document.getElementById("name").value.trim();'
    + '  var desc=document.getElementById("description").value.trim();'
    + '  if(!name)return;'
    + '  btn.textContent="Adding...";btn.disabled=true;'
    + '  try{var res=await fetch("/items",{method:"POST",headers:{"Content-Type":"application/json"},body:JSON.stringify({name:name,description:desc})});'
    + '    if(!res.ok)throw new Error("Failed");'
    + '    var item=await res.json();items.unshift(item);render();'
    + '    document.getElementById("itemForm").reset();showToast("Item added successfully.","success");'
    + '  }catch(e){showToast("Failed to add item.","error");}'
    + '  finally{btn.textContent="Add Item";btn.disabled=false;}'
    + '});'
    + 'async function del(id){try{await fetch("/items/"+id,{method:"DELETE"});items=items.filter(function(i){return i.id!==id;});render();}catch(e){showToast("Failed to delete.","error");}}'
    + 'loadItems();'
    + '</script></body></html>');
});

initDB()
  .then(function() {
    app.listen(8080, '0.0.0.0', function() {
      console.log('Listening on :8080');
    });
  })
  .catch(function(err) {
    console.error('Startup failed:', err);
    process.exit(1);
  });
APP

# ── Systemd service ───────────────────────────────────────
cat > /etc/systemd/system/webapp.service <<SVC
[Unit]
Description=Items Web App
After=network.target

[Service]
WorkingDirectory=/opt/webapp
ExecStart=/usr/bin/node server.js
Restart=always
Environment=DB_HOST=${db_host}
Environment=DB_PORT=${db_port}
Environment=DB_NAME=${db_name}
Environment=DB_USER=${db_user}
Environment=DB_PASSWORD=${db_password}
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
SVC

systemctl daemon-reload
systemctl enable --now webapp

# Open app port
systemctl start firewalld
# Wait until firewalld is actually responsive
until firewall-cmd --state 2>/dev/null | grep -q running; do
  sleep 1
done
firewall-cmd --permanent --add-port=8080/tcp
firewall-cmd --reload

echo "Bootstrap complete"
