/**
 * Mighty Chat Progressive Web App (PWA)
 * Complete User Authentication, Contact Management, Cross-Tab Sync & Hardened Security
 */

// ==========================================
// 1. Strict Sanitization & Security Defense
// ==========================================
function escapeHtml(str) {
  if (str === null || str === undefined) return '';
  const s = String(str);
  const map = {
    '&': '&amp;',
    '<': '&lt;',
    '>': '&gt;',
    '"': '&quot;',
    "'": '&#039;',
    '`': '&#x60;',
    '/': '&#x2F;'
  };
  return s.replace(/[&<>"'`/]/g, (char) => map[char]);
}

function sanitizeUrl(rawUrl, fallback = './assets/user.png') {
  if (!rawUrl || typeof rawUrl !== 'string') return fallback;
  const trimmed = rawUrl.trim();
  if (/^(https?:\/\/|\.\/|\/|blob:|data:image\/(png|jpeg|jpg|webp|gif);base64,)/i.test(trimmed)) {
    return trimmed.replace(/[\r\n\t]/g, '');
  }
  return fallback;
}

// ==========================================
// 2. Cross-Tab Real-Time Sync (BroadcastChannel)
// ==========================================
const chatBroadcast = ('BroadcastChannel' in window) 
  ? new BroadcastChannel('mighty_chat_realtime_channel') 
  : null;

if (chatBroadcast) {
  chatBroadcast.onmessage = (event) => {
    const data = event.data;
    if (!data) return;

    if (data.type === 'NEW_MESSAGE') {
      handleIncomingCrossTabMessage(data.payload);
    } else if (data.type === 'USER_CREATED') {
      loadRegisteredUsers();
    }
  };
}

// ==========================================
// 3. User Directory & Account Store
// ==========================================
const DEFAULT_ACCOUNTS = [
  { id: 'user_john', name: 'John Doe', email: 'john@mightychat.com', avatar: './assets/user.png', status: 'Hey there! I am using Mighty Chat' },
  { id: 'user_sarah', name: 'Sarah Connor', email: 'sarah@mightychat.com', avatar: './assets/user.png', status: 'Focused on the Flutter & PWA launch 🚀' },
  { id: 'user_alex', name: 'Alex Rivera', email: 'alex@mightychat.com', avatar: './assets/user.png', status: 'Backend & Firebase architect 💻' },
  { id: 'user_emily', name: 'Emily Watson', email: 'emily@mightychat.com', avatar: './assets/user.png', status: 'UI/UX Designer & Product Specialist ✨' }
];

function getRegisteredUsers() {
  const saved = localStorage.getItem('mighty_registered_users');
  if (saved) {
    try { return JSON.parse(saved); } catch (e) {}
  }
  localStorage.setItem('mighty_registered_users', JSON.stringify(DEFAULT_ACCOUNTS));
  return DEFAULT_ACCOUNTS;
}

function saveRegisteredUsers(users) {
  localStorage.setItem('mighty_registered_users', JSON.stringify(users));
  if (chatBroadcast) {
    chatBroadcast.postMessage({ type: 'USER_CREATED' });
  }
}

// Active Current User
let currentUser = null;

function initCurrentUser() {
  const saved = localStorage.getItem('mighty_current_user');
  if (saved) {
    try { currentUser = JSON.parse(saved); } catch (e) {}
  }
  if (!currentUser) {
    currentUser = getRegisteredUsers()[0];
    localStorage.setItem('mighty_current_user', JSON.stringify(currentUser));
  }
  updateUIForCurrentUser();
}

function updateUIForCurrentUser() {
  const nameElem = document.getElementById('my-name');
  const avatarElem = document.getElementById('my-avatar');
  const authAvatar = document.getElementById('auth-current-avatar');
  const authSubtitle = document.getElementById('auth-current-subtitle');
  const profileNameInput = document.getElementById('profile-name-input');
  const profileStatusInput = document.getElementById('profile-status-input');

  if (nameElem) nameElem.textContent = currentUser.name;
  if (avatarElem) avatarElem.src = sanitizeUrl(currentUser.avatar);
  if (authAvatar) authAvatar.src = sanitizeUrl(currentUser.avatar);
  if (authSubtitle) authSubtitle.textContent = `Signed in as ${currentUser.name} (${currentUser.email || 'Local'})`;
  if (profileNameInput) profileNameInput.value = currentUser.name;
  if (profileStatusInput) profileStatusInput.value = currentUser.status || '';
}

// ==========================================
// 4. Conversation & Contact Store
// ==========================================
const DEFAULT_CONVERSATIONS = [
  {
    id: 'c1',
    participantId: 'user_sarah',
    name: 'Sarah Connor',
    avatar: './assets/user.png',
    isGroup: false,
    online: true,
    lastSeen: 'online',
    unreadCount: 0,
    messages: [
      { id: 'm1', senderId: 'user_sarah', sender: 'them', text: 'Hey! Are user account creation and contact adding ready?', time: '10:15 AM', status: 'read' },
      { id: 'm2', senderId: 'user_john', sender: 'me', text: 'Yes, full account switching, contact creation, and cross-tab chatting are live!', time: '10:16 AM', status: 'read' },
      { id: 'm3', senderId: 'user_sarah', sender: 'them', text: 'Awesome! Open a second browser tab as Sarah to test live 2-way chat.', time: '10:18 AM', status: 'delivered' }
    ]
  },
  {
    id: 'c2',
    participantId: 'group_mobile',
    name: 'Mobile Engineering Team',
    avatar: './assets/group_user.jpg',
    isGroup: true,
    online: true,
    lastSeen: '12 members active',
    unreadCount: 0,
    messages: [
      { id: 'gm1', senderId: 'user_alex', sender: 'them', senderName: 'Alex Rivera', text: 'Firestore security rules and multi-tenancy are deployed.', time: '09:30 AM', status: 'read' },
      { id: 'gm2', senderId: 'user_emily', sender: 'them', senderName: 'Emily Watson', text: 'Contact addition and group creation modals look super clean!', time: '09:42 AM', status: 'read' }
    ]
  }
];

function getStoredConversations() {
  const key = `mighty_conversations_${currentUser ? currentUser.id : 'default'}`;
  const saved = localStorage.getItem(key);
  if (saved) {
    try { return JSON.parse(saved); } catch (e) {}
  }
  return JSON.parse(JSON.stringify(DEFAULT_CONVERSATIONS));
}

function saveStoredConversations(convs) {
  const key = `mighty_conversations_${currentUser ? currentUser.id : 'default'}`;
  localStorage.setItem(key, JSON.stringify(convs));
}

let conversations = [];
let activeChatId = 'c1';
let activePendingAttachment = null;
let mediaRecorder = null;
let audioChunks = [];
let recordingInterval = null;
let recordingSeconds = 0;
let callTimerInterval = null;
let callDuration = 0;
let localMediaStream = null;

// ==========================================
// 5. Stories
// ==========================================
const storiesData = [
  {
    id: 's0',
    userName: 'My Status',
    avatar: './assets/user.png',
    hasUnseen: false,
    media: './assets/app_icon.png',
    caption: 'Tap to share an update'
  },
  {
    id: 's1',
    userName: 'Sarah',
    avatar: './assets/user.png',
    hasUnseen: true,
    media: './assets/group_user.jpg',
    caption: 'Testing multi-user accounts on Mighty Chat! 🚀'
  },
  {
    id: 's2',
    userName: 'Alex R.',
    avatar: './assets/user.png',
    hasUnseen: true,
    media: './assets/default_wallpaper_dark.jpg',
    caption: 'Real-time WebSocket & BroadcastChannel sync verified.'
  }
];

function renderStories() {
  const container = document.getElementById('stories-container');
  if (!container) return;
  container.innerHTML = '';

  storiesData.forEach((story) => {
    const item = document.createElement('div');
    item.className = 'flex flex-col items-center flex-shrink-0 cursor-pointer group';
    
    const ringClass = story.hasUnseen 
      ? 'p-0.5 rounded-full bg-gradient-to-tr from-amber-500 to-brand-500' 
      : 'p-0.5 rounded-full bg-gray-200 dark:bg-gray-700';

    const safeAvatar = sanitizeUrl(story.avatar);
    const safeName = escapeHtml(story.userName);

    item.innerHTML = `
      <div class="${ringClass} transition transform group-hover:scale-105">
        <div class="p-0.5 bg-white dark:bg-dark-panel rounded-full">
          <img src="${safeAvatar}" class="w-12 h-12 rounded-full object-cover" alt="${safeName}">
        </div>
      </div>
      <span class="text-[11px] text-gray-700 dark:text-gray-300 truncate max-w-[64px] mt-1 font-medium">${safeName}</span>
    `;

    item.addEventListener('click', () => openStoryModal(story));
    container.appendChild(item);
  });
}

// ==========================================
// 6. Render Chat List
// ==========================================
function renderChatList(filterQuery = '') {
  const chatList = document.getElementById('chat-list');
  if (!chatList) return;
  chatList.innerHTML = '';

  const query = filterQuery.toLowerCase().trim();
  const filtered = conversations.filter(c => {
    if (!query) return true;
    const nameMatch = c.name.toLowerCase().includes(query);
    const msgMatch = c.messages.some(m => m.text && m.text.toLowerCase().includes(query));
    return nameMatch || msgMatch;
  });

  if (filtered.length === 0) {
    const emptyDiv = document.createElement('div');
    emptyDiv.className = 'p-8 text-center text-gray-400 text-xs';
    emptyDiv.textContent = filterQuery ? `No chats matching "${filterQuery}"` : 'No conversations yet. Click + to add a contact!';
    chatList.appendChild(emptyDiv);
    return;
  }

  filtered.forEach(chat => {
    const isActive = chat.id === activeChatId;
    const lastMsg = chat.messages[chat.messages.length - 1] || { text: '', time: '' };
    
    const item = document.createElement('div');
    item.className = `p-3.5 flex items-center space-x-3 cursor-pointer transition ${
      isActive 
        ? 'bg-brand-50/70 dark:bg-dark-hover border-l-4 border-brand-600' 
        : 'hover:bg-gray-50 dark:hover:bg-dark-hover/60'
    }`;

    const safeAvatar = sanitizeUrl(chat.avatar);
    const safeName = escapeHtml(chat.name);
    const safeTime = escapeHtml(lastMsg.time || '');
    const previewText = lastMsg.image ? '📷 Photo' : (lastMsg.audio ? '🎵 Voice Note' : escapeHtml(lastMsg.text || ''));

    let statusCheckmarks = '';
    if (lastMsg.sender === 'me') {
      const isBlue = lastMsg.status === 'read';
      const color = isBlue ? 'text-blue-500' : 'text-gray-400';
      statusCheckmarks = `
        <svg class="w-3.5 h-3.5 mr-1 ${color} inline flex-shrink-0" fill="currentColor" viewBox="0 0 20 20">
          <path d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z"/>
        </svg>
      `;
    }

    item.innerHTML = `
      <div class="relative flex-shrink-0">
        <img src="${safeAvatar}" class="w-12 h-12 rounded-full object-cover border border-gray-200 dark:border-gray-700" alt="${safeName}">
        ${chat.online ? '<span class="absolute bottom-0 right-0 w-3 h-3 bg-emerald-500 border-2 border-white dark:border-dark-panel rounded-full"></span>' : ''}
      </div>
      <div class="flex-1 min-w-0">
        <div class="flex items-center justify-between">
          <h4 class="text-sm font-semibold text-gray-900 dark:text-gray-100 truncate">${safeName}</h4>
          <span class="text-[11px] text-gray-400 font-medium">${safeTime}</span>
        </div>
        <div class="flex items-center justify-between mt-1">
          <p class="text-xs text-gray-500 dark:text-gray-400 truncate flex items-center pr-2">
            ${statusCheckmarks}
            <span class="truncate">${previewText}</span>
          </p>
          ${chat.unreadCount > 0 ? `
            <span class="bg-brand-600 text-white text-[10px] font-bold rounded-full h-5 min-w-[20px] px-1.5 flex items-center justify-center shadow-sm">
              ${parseInt(chat.unreadCount, 10)}
            </span>
          ` : ''}
        </div>
      </div>
    `;

    item.addEventListener('click', () => {
      selectChat(chat.id);
    });

    chatList.appendChild(item);
  });
}

// ==========================================
// 7. Select & Render Active Chat
// ==========================================
function selectChat(chatId) {
  const chat = conversations.find(c => c.id === chatId);
  if (!chat) {
    if (conversations.length > 0) {
      selectChat(conversations[0].id);
    }
    return;
  }

  activeChatId = chatId;
  chat.unreadCount = 0;
  saveStoredConversations(conversations);

  const sidebar = document.getElementById('sidebar');
  const chatWindow = document.getElementById('chat-window');
  const noChatSelected = document.getElementById('no-chat-selected');
  const activeChatContainer = document.getElementById('active-chat-container');

  sidebar.classList.add('hidden', 'md:flex');
  chatWindow.classList.remove('hidden');
  noChatSelected.classList.add('hidden');
  activeChatContainer.classList.remove('hidden');

  document.getElementById('chat-header-avatar').src = sanitizeUrl(chat.avatar);
  document.getElementById('chat-header-name').textContent = chat.name;
  document.getElementById('chat-header-subtitle').textContent = chat.lastSeen;
  document.getElementById('chat-header-subtitle').className = chat.online 
    ? 'text-xs text-emerald-600 dark:text-emerald-400 font-medium' 
    : 'text-xs text-gray-400 font-normal';
  
  const dot = document.getElementById('chat-header-status-dot');
  if (chat.online) dot.classList.remove('hidden'); else dot.classList.add('hidden');

  renderChatList();
  renderMessages();
}

document.getElementById('back-to-list-btn').addEventListener('click', () => {
  const sidebar = document.getElementById('sidebar');
  const chatWindow = document.getElementById('chat-window');
  sidebar.classList.remove('hidden');
  chatWindow.classList.add('hidden');
});

// ==========================================
// 8. Render Message Thread
// ==========================================
function renderMessages() {
  const container = document.getElementById('messages-container');
  if (!container) return;
  container.innerHTML = '';

  const chat = conversations.find(c => c.id === activeChatId);
  if (!chat || chat.messages.length === 0) {
    container.innerHTML = `
      <div class="h-full flex flex-col items-center justify-center text-gray-400 text-xs">
        <img src="./assets/app_icon.png" class="w-14 h-14 rounded-2xl opacity-75 mb-2" alt="App">
        <span>No messages yet. Send a greeting to start chatting!</span>
      </div>
    `;
    return;
  }

  const dateDivider = document.createElement('div');
  dateDivider.className = 'flex justify-center my-2';
  dateDivider.innerHTML = `
    <span class="bg-gray-200/80 dark:bg-dark-card/90 text-gray-600 dark:text-gray-300 text-[11px] font-semibold px-3 py-1 rounded-lg shadow-sm">
      Today
    </span>
  `;
  container.appendChild(dateDivider);

  chat.messages.forEach(msg => {
    const isMe = msg.sender === 'me';
    const row = document.createElement('div');
    row.className = `flex ${isMe ? 'justify-end' : 'justify-start'} group`;

    const bubbleBg = isMe 
      ? 'bg-brand-600 text-white rounded-br-none shadow-sm' 
      : 'bg-white dark:bg-dark-card text-gray-900 dark:text-gray-100 rounded-bl-none shadow-sm border border-gray-100 dark:border-dark-border/40';

    let contentHtml = '';

    if (msg.image) {
      const safeImgUrl = sanitizeUrl(msg.image, './assets/app_icon.png');
      contentHtml += `
        <div class="mb-1.5 overflow-hidden rounded-xl cursor-pointer">
          <img src="${safeImgUrl}" class="max-w-[260px] md:max-w-[320px] max-h-64 object-cover hover:opacity-95 transition" alt="Attachment">
        </div>
      `;
    }

    if (msg.audio) {
      const safeAudioUrl = sanitizeUrl(msg.audio, './assets/callingtone.mp3');
      contentHtml += `
        <div class="flex items-center space-x-3 py-1">
          <button data-audio-src="${safeAudioUrl}" class="voice-play-btn p-2 rounded-full ${isMe ? 'bg-white text-brand-700' : 'bg-brand-600 text-white'} shadow">
            <svg class="w-4 h-4 fill-current" viewBox="0 0 24 24"><path d="M8 5v14l11-7z"/></svg>
          </button>
          <div class="flex-1">
            <div class="flex items-center space-x-0.5 h-6">
              <span class="w-1 h-3 bg-current opacity-60 rounded-full"></span>
              <span class="w-1 h-5 bg-current opacity-80 rounded-full"></span>
              <span class="w-1 h-2 bg-current opacity-40 rounded-full"></span>
              <span class="w-1 h-6 bg-current rounded-full"></span>
              <span class="w-1 h-4 bg-current opacity-70 rounded-full"></span>
              <span class="w-1 h-3 bg-current opacity-50 rounded-full"></span>
            </div>
            <span class="text-[10px] opacity-80">0:14</span>
          </div>
        </div>
      `;
    }

    if (msg.text) {
      contentHtml += `<p class="text-sm whitespace-pre-wrap leading-relaxed">${escapeHtml(msg.text)}</p>`;
    }

    const senderHeader = (!isMe && chat.isGroup && msg.senderName) 
      ? `<div class="text-[11px] font-bold text-amber-500 mb-0.5">${escapeHtml(msg.senderName)}</div>` 
      : '';

    let statusIcon = '';
    if (isMe) {
      const isBlue = msg.status === 'read';
      statusIcon = `
        <svg class="w-3.5 h-3.5 ml-1 ${isBlue ? 'text-blue-300' : 'text-gray-200'} inline" fill="currentColor" viewBox="0 0 20 20">
          <path d="M16.707 5.293a1 1 0 010 1.414l-8 8a1 1 0 01-1.414 0l-4-4a1 1 0 011.414-1.414L8 12.586l7.293-7.293a1 1 0 011.414 0z"/>
        </svg>
      `;
    }

    row.innerHTML = `
      <div class="max-w-[85%] md:max-w-[70%] p-3 rounded-2xl ${bubbleBg} relative">
        ${senderHeader}
        ${contentHtml}
        <div class="flex items-center justify-end space-x-1 mt-1 text-[10px] opacity-75">
          <span>${escapeHtml(msg.time)}</span>
          ${statusIcon}
        </div>
      </div>
    `;

    container.appendChild(row);
  });

  container.querySelectorAll('.voice-play-btn').forEach(btn => {
    btn.addEventListener('click', (e) => {
      const src = e.currentTarget.getAttribute('data-audio-src');
      if (src) {
        const audio = new Audio(src);
        audio.play().catch(err => console.warn('[Audio] Playback failed:', err));
      }
    });
  });

  container.scrollTop = container.scrollHeight;
}

// ==========================================
// 9. Send Message & Cross-Tab Broadcast
// ==========================================
const messageInput = document.getElementById('message-input');
const sendBtn = document.getElementById('send-btn');
const voiceRecordBtn = document.getElementById('voice-record-btn');

messageInput.addEventListener('input', () => {
  const hasText = messageInput.value.trim().length > 0 || activePendingAttachment != null;
  if (hasText) {
    sendBtn.classList.remove('hidden');
    voiceRecordBtn.classList.add('hidden');
  } else {
    sendBtn.classList.add('hidden');
    voiceRecordBtn.classList.remove('hidden');
  }

  messageInput.style.height = 'auto';
  messageInput.style.height = `${Math.min(messageInput.scrollHeight, 120)}px`;
});

messageInput.addEventListener('keydown', (e) => {
  if (e.key === 'Enter' && !e.shiftKey) {
    e.preventDefault();
    sendMessage();
  }
});

sendBtn.addEventListener('click', sendMessage);

function sendMessage() {
  const text = messageInput.value.trim();
  if (!text && !activePendingAttachment) return;

  const chat = conversations.find(c => c.id === activeChatId);
  if (!chat) return;

  const now = new Date();
  const timeStr = now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });

  const newMsg = {
    id: `m_${Date.now()}_${Math.random().toString(36).substr(2, 5)}`,
    senderId: currentUser.id,
    senderName: currentUser.name,
    sender: 'me',
    text: text,
    image: activePendingAttachment ? activePendingAttachment.dataUrl : null,
    time: timeStr,
    status: 'sent'
  };

  chat.messages.push(newMsg);
  saveStoredConversations(conversations);

  // Broadcast to other browser tabs in real time
  if (chatBroadcast) {
    chatBroadcast.postMessage({
      type: 'NEW_MESSAGE',
      payload: {
        chatId: chat.id,
        participantId: chat.participantId,
        fromUser: currentUser,
        message: newMsg
      }
    });
  }

  messageInput.value = '';
  messageInput.style.height = 'auto';
  clearAttachment();
  sendBtn.classList.add('hidden');
  voiceRecordBtn.classList.remove('hidden');

  renderMessages();
  renderChatList();

  setTimeout(() => {
    newMsg.status = 'delivered';
    renderMessages();
    saveStoredConversations(conversations);
  }, 400);

  // If chat is with a bot or demo contact and no other tab handles it, simulate response
  if (!chat.isGroup && chat.participantId !== currentUser.id) {
    simulateAutomatedContactReply(chat);
  }
}

function simulateAutomatedContactReply(chat) {
  const subtitle = document.getElementById('chat-header-subtitle');
  if (chat.id === activeChatId && subtitle) {
    subtitle.textContent = 'typing...';
    subtitle.className = 'text-xs text-brand-600 dark:text-brand-400 font-semibold animate-pulse';
  }

  setTimeout(() => {
    const replies = [
      "Message received loud and clear! 👍",
      "I love this chat interface, looks clean and fast.",
      "Got it! Tested on both desktop and mobile.",
      "Account creation and contact sync are working nicely.",
      "Let's test audio and video call next!"
    ];
    const replyText = replies[Math.floor(Math.random() * replies.length)];
    const now = new Date();
    const timeStr = now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });

    chat.messages.push({
      id: `reply_${Date.now()}`,
      senderId: chat.participantId || 'them',
      sender: 'them',
      text: replyText,
      time: timeStr,
      status: 'read'
    });

    saveStoredConversations(conversations);

    if (chat.id === activeChatId && subtitle) {
      subtitle.textContent = 'online';
      subtitle.className = 'text-xs text-emerald-600 dark:text-emerald-400 font-medium';
    }

    renderMessages();
    renderChatList();

    if ('Notification' in window && Notification.permission === 'granted') {
      new Notification(`Mighty Chat: ${chat.name}`, {
        body: replyText,
        icon: './icons/icon-192.png'
      });
    }
  }, 1600);
}

// Handle cross-tab incoming messages
function handleIncomingCrossTabMessage(payload) {
  if (!payload || !payload.fromUser) return;

  // Find if we have a conversation with the sender
  let targetChat = conversations.find(c => c.participantId === payload.fromUser.id || c.id === payload.chatId);

  if (!targetChat) {
    // Automatically create conversation with new contact!
    targetChat = {
      id: `chat_${payload.fromUser.id}`,
      participantId: payload.fromUser.id,
      name: payload.fromUser.name,
      avatar: payload.fromUser.avatar || './assets/user.png',
      isGroup: false,
      online: true,
      lastSeen: 'online',
      unreadCount: 0,
      messages: []
    };
    conversations.unshift(targetChat);
  }

  const incomingMsg = {
    ...payload.message,
    sender: 'them'
  };

  targetChat.messages.push(incomingMsg);
  if (activeChatId !== targetChat.id) {
    targetChat.unreadCount = (targetChat.unreadCount || 0) + 1;
  }

  saveStoredConversations(conversations);
  renderChatList();
  if (activeChatId === targetChat.id) {
    renderMessages();
  }

  // Play incoming alert tone
  try {
    const audio = new Audio('./assets/callingtone.mp3');
    audio.play().catch(() => {});
  } catch (e) {}
}

// ==========================================
// 10. Modals: Add Contact & Start New Chat
// ==========================================
const newChatBtn = document.getElementById('new-chat-btn');
const newChatModal = document.getElementById('new-chat-modal');
const closeNewChatBtn = document.getElementById('close-new-chat-btn');
const startChatBtn = document.getElementById('start-chat-btn');
const createGroupBtn = document.getElementById('create-group-btn');
const newContactName = document.getElementById('new-contact-name');
const newContactIdentifier = document.getElementById('new-contact-identifier');
const newContactMessage = document.getElementById('new-contact-message');

newChatBtn.addEventListener('click', () => {
  newContactName.value = '';
  newContactIdentifier.value = '';
  newContactMessage.value = '';
  newChatModal.classList.remove('hidden');
});

closeNewChatBtn.addEventListener('click', () => {
  newChatModal.classList.add('hidden');
});

startChatBtn.addEventListener('click', () => {
  const name = newContactName.value.trim();
  const identifier = newContactIdentifier.value.trim();
  const initialMsg = newContactMessage.value.trim();

  if (!name) {
    alert('Please enter a contact name.');
    return;
  }

  const newChatId = `c_${Date.now()}`;
  const now = new Date();
  const timeStr = now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });

  const newConversation = {
    id: newChatId,
    participantId: `usr_${Date.now()}`,
    name: name,
    avatar: './assets/user.png',
    isGroup: false,
    online: true,
    lastSeen: 'Active now',
    unreadCount: 0,
    messages: []
  };

  if (initialMsg) {
    newConversation.messages.push({
      id: `m_${Date.now()}`,
      senderId: currentUser.id,
      sender: 'me',
      text: initialMsg,
      time: timeStr,
      status: 'sent'
    });
  }

  conversations.unshift(newConversation);
  saveStoredConversations(conversations);

  newChatModal.classList.add('hidden');
  selectChat(newChatId);
});

createGroupBtn.addEventListener('click', () => {
  const groupName = prompt('Enter Group Name:', 'Project Team');
  if (!groupName || !groupName.trim()) return;

  const newChatId = `grp_${Date.now()}`;
  const newConversation = {
    id: newChatId,
    name: groupName.trim(),
    avatar: './assets/group_user.jpg',
    isGroup: true,
    online: true,
    lastSeen: 'Multiple members',
    unreadCount: 0,
    messages: [
      {
        id: `gm_${Date.now()}`,
        senderId: currentUser.id,
        sender: 'me',
        text: `Welcome to ${groupName.trim()}! Group created.`,
        time: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
        status: 'read'
      }
    ]
  };

  conversations.unshift(newConversation);
  saveStoredConversations(conversations);
  newChatModal.classList.add('hidden');
  selectChat(newChatId);
});

// ==========================================
// 11. Modals: User Auth & Account Switcher
// ==========================================
const myProfileTrigger = document.getElementById('my-profile-trigger');
const authModal = document.getElementById('auth-modal');
const closeAuthBtn = document.getElementById('close-auth-btn');

const authTabProfile = document.getElementById('auth-tab-profile');
const authTabSwitch = document.getElementById('auth-tab-switch');
const authTabCreate = document.getElementById('auth-tab-create');

const authViewProfile = document.getElementById('auth-view-profile');
const authViewSwitch = document.getElementById('auth-view-switch');
const authViewCreate = document.getElementById('auth-view-create');

const saveProfileBtn = document.getElementById('save-profile-btn');
const logoutBtn = document.getElementById('logout-btn');
const submitCreateAccountBtn = document.getElementById('submit-create-account-btn');

myProfileTrigger.addEventListener('click', () => {
  updateUIForCurrentUser();
  switchAuthTab('profile');
  authModal.classList.remove('hidden');
});

closeAuthBtn.addEventListener('click', () => {
  authModal.classList.add('hidden');
});

function switchAuthTab(tab) {
  authTabProfile.className = 'py-2 px-3 border-b-2 border-transparent text-gray-500 hover:text-gray-700 dark:hover:text-gray-300';
  authTabSwitch.className = 'py-2 px-3 border-b-2 border-transparent text-gray-500 hover:text-gray-700 dark:hover:text-gray-300';
  authTabCreate.className = 'py-2 px-3 border-b-2 border-transparent text-gray-500 hover:text-gray-700 dark:hover:text-gray-300';

  authViewProfile.classList.add('hidden');
  authViewSwitch.classList.add('hidden');
  authViewCreate.classList.add('hidden');

  if (tab === 'profile') {
    authTabProfile.className = 'py-2 px-3 border-b-2 border-brand-500 text-brand-600 dark:text-brand-400 font-bold';
    authViewProfile.classList.remove('hidden');
  } else if (tab === 'switch') {
    authTabSwitch.className = 'py-2 px-3 border-b-2 border-brand-500 text-brand-600 dark:text-brand-400 font-bold';
    authViewSwitch.classList.remove('hidden');
    loadRegisteredUsers();
  } else if (tab === 'create') {
    authTabCreate.className = 'py-2 px-3 border-b-2 border-brand-500 text-brand-600 dark:text-brand-400 font-bold';
    authViewCreate.classList.remove('hidden');
  }
}

authTabProfile.addEventListener('click', () => switchAuthTab('profile'));
authTabSwitch.addEventListener('click', () => switchAuthTab('switch'));
authTabCreate.addEventListener('click', () => switchAuthTab('create'));

saveProfileBtn.addEventListener('click', () => {
  const name = document.getElementById('profile-name-input').value.trim();
  const status = document.getElementById('profile-status-input').value.trim();
  if (name) currentUser.name = name;
  currentUser.status = status;
  localStorage.setItem('mighty_current_user', JSON.stringify(currentUser));
  updateUIForCurrentUser();
  authModal.classList.add('hidden');
});

logoutBtn.addEventListener('click', () => {
  if (confirm('Sign out from this session?')) {
    localStorage.removeItem('mighty_current_user');
    initCurrentUser();
    conversations = getStoredConversations();
    renderChatList();
    selectChat(conversations[0]?.id);
    authModal.classList.add('hidden');
  }
});

function loadRegisteredUsers() {
  const listContainer = document.getElementById('switch-accounts-list');
  if (!listContainer) return;
  listContainer.innerHTML = '';

  const allUsers = getRegisteredUsers();
  allUsers.forEach(u => {
    const isCurrent = u.id === currentUser.id;
    const btn = document.createElement('div');
    btn.className = `p-2.5 rounded-xl border flex items-center justify-between cursor-pointer transition ${
      isCurrent ? 'bg-brand-50 dark:bg-brand-950/40 border-brand-500' : 'bg-gray-50 dark:bg-dark-card border-gray-200 dark:border-dark-border hover:border-brand-400'
    }`;
    btn.innerHTML = `
      <div class="flex items-center space-x-2.5">
        <img src="${sanitizeUrl(u.avatar)}" class="w-8 h-8 rounded-full object-cover" alt="${escapeHtml(u.name)}">
        <div>
          <div class="text-xs font-bold text-gray-900 dark:text-gray-100">${escapeHtml(u.name)}</div>
          <div class="text-[10px] text-gray-500">${escapeHtml(u.email || u.id)}</div>
        </div>
      </div>
      ${isCurrent ? '<span class="text-[10px] bg-brand-600 text-white font-bold px-2 py-0.5 rounded-full">Active</span>' : '<button class="text-xs text-brand-600 dark:text-brand-400 font-semibold hover:underline">Switch</button>'}
    `;

    if (!isCurrent) {
      btn.addEventListener('click', () => {
        currentUser = u;
        localStorage.setItem('mighty_current_user', JSON.stringify(currentUser));
        initCurrentUser();
        conversations = getStoredConversations();
        renderChatList();
        selectChat(conversations[0]?.id);
        authModal.classList.add('hidden');
      });
    }

    listContainer.appendChild(btn);
  });
}

submitCreateAccountBtn.addEventListener('click', () => {
  const nameInput = document.getElementById('create-user-name');
  const emailInput = document.getElementById('create-user-email');
  const passInput = document.getElementById('create-user-pass');

  const name = nameInput.value.trim();
  const email = emailInput.value.trim();
  const pass = passInput.value.trim();

  if (!name || !email) {
    alert('Please provide a name and email address.');
    return;
  }

  const allUsers = getRegisteredUsers();
  if (allUsers.some(u => u.email === email)) {
    alert('An account with this email already exists.');
    return;
  }

  const newUser = {
    id: `user_${Date.now()}`,
    name: name,
    email: email,
    avatar: './assets/user.png',
    status: 'Hey there! I am using Mighty Chat'
  };

  allUsers.push(newUser);
  saveRegisteredUsers(allUsers);

  // Switch to new user
  currentUser = newUser;
  localStorage.setItem('mighty_current_user', JSON.stringify(currentUser));
  initCurrentUser();
  conversations = getStoredConversations();
  renderChatList();
  selectChat(conversations[0]?.id);

  nameInput.value = '';
  emailInput.value = '';
  passInput.value = '';
  authModal.classList.add('hidden');
  alert(`Welcome, ${newUser.name}! Account created and signed in.`);
});

// ==========================================
// 12. Modals: Chat Options Menu
// ==========================================
const chatOptionsBtn = document.getElementById('chat-options-btn');
const chatOptionsModal = document.getElementById('chat-options-modal');
const closeOptionsBtn = document.getElementById('close-options-btn');
const optClearChat = document.getElementById('opt-clear-chat');
const optMuteChat = document.getElementById('opt-mute-chat');
const optDeleteChat = document.getElementById('opt-delete-chat');

chatOptionsBtn.addEventListener('click', () => {
  chatOptionsModal.classList.remove('hidden');
});

closeOptionsBtn.addEventListener('click', () => {
  chatOptionsModal.classList.add('hidden');
});

optClearChat.addEventListener('click', () => {
  const chat = conversations.find(c => c.id === activeChatId);
  if (!chat) return;
  if (confirm(`Clear all messages in "${chat.name}"?`)) {
    chat.messages = [];
    saveStoredConversations(conversations);
    renderMessages();
    renderChatList();
    chatOptionsModal.classList.add('hidden');
  }
});

optMuteChat.addEventListener('click', () => {
  alert('Notifications muted for this conversation.');
  chatOptionsModal.classList.add('hidden');
});

optDeleteChat.addEventListener('click', () => {
  const chat = conversations.find(c => c.id === activeChatId);
  if (!chat) return;
  if (confirm(`Delete conversation "${chat.name}"?`)) {
    conversations = conversations.filter(c => c.id !== activeChatId);
    saveStoredConversations(conversations);
    activeChatId = conversations[0]?.id || null;
    renderChatList();
    if (activeChatId) {
      selectChat(activeChatId);
    } else {
      document.getElementById('no-chat-selected').classList.remove('hidden');
      document.getElementById('active-chat-container').classList.add('hidden');
    }
    chatOptionsModal.classList.add('hidden');
  }
});

// ==========================================
// 13. Attachments, Voice Notes & Calling
// ==========================================
const attachFileBtn = document.getElementById('attach-file-btn');
const fileInput = document.getElementById('file-input');
const attachmentPreviewBar = document.getElementById('attachment-preview-bar');
const imagePreview = document.getElementById('image-preview');
const attachmentName = document.getElementById('attachment-name');
const cancelAttachmentBtn = document.getElementById('cancel-attachment-btn');

attachFileBtn.addEventListener('click', () => fileInput.click());

fileInput.addEventListener('change', (e) => {
  const file = e.target.files[0];
  if (!file) return;

  if (file.size > 15 * 1024 * 1024) {
    alert('File size exceeds the 15MB limit.');
    fileInput.value = '';
    return;
  }

  const allowedTypes = ['image/jpeg', 'image/png', 'image/webp', 'image/gif', 'application/pdf', 'audio/mpeg', 'audio/wav'];
  if (!allowedTypes.includes(file.type)) {
    alert('Unsupported file format.');
    fileInput.value = '';
    return;
  }

  const reader = new FileReader();
  reader.onload = (event) => {
    activePendingAttachment = {
      file: file,
      dataUrl: event.target.result,
      name: file.name
    };
    imagePreview.src = event.target.result;
    attachmentName.textContent = file.name;
    attachmentPreviewBar.classList.remove('hidden');
    sendBtn.classList.remove('hidden');
    voiceRecordBtn.classList.add('hidden');
  };
  reader.readAsDataURL(file);
});

cancelAttachmentBtn.addEventListener('click', clearAttachment);

function clearAttachment() {
  activePendingAttachment = null;
  fileInput.value = '';
  attachmentPreviewBar.classList.add('hidden');
  if (messageInput.value.trim().length === 0) {
    sendBtn.classList.add('hidden');
    voiceRecordBtn.classList.remove('hidden');
  }
}

// Voice Note Recording
const recordingBar = document.getElementById('recording-bar');
const recordingTimer = document.getElementById('recording-timer');
const cancelRecordingBtn = document.getElementById('cancel-recording-btn');
const stopAndSendRecordingBtn = document.getElementById('stop-and-send-recording-btn');

voiceRecordBtn.addEventListener('click', async () => {
  try {
    const stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    mediaRecorder = new MediaRecorder(stream);
    audioChunks = [];
    mediaRecorder.ondataavailable = (e) => {
      if (e.data.size > 0) audioChunks.push(e.data);
    };
    mediaRecorder.start();
    startRecordingTimer();
    recordingBar.classList.remove('hidden');
  } catch (err) {
    startRecordingTimer();
    recordingBar.classList.remove('hidden');
  }
});

function startRecordingTimer() {
  recordingSeconds = 0;
  recordingTimer.textContent = '0:00';
  clearInterval(recordingInterval);
  recordingInterval = setInterval(() => {
    recordingSeconds++;
    const m = Math.floor(recordingSeconds / 60);
    const s = recordingSeconds % 60;
    recordingTimer.textContent = `${m}:${s < 10 ? '0' : ''}${s}`;
  }, 1000);
}

function cleanupAudioRecording() {
  clearInterval(recordingInterval);
  if (mediaRecorder && mediaRecorder.state !== 'inactive') {
    mediaRecorder.stop();
    if (mediaRecorder.stream) {
      mediaRecorder.stream.getTracks().forEach(t => t.stop());
    }
  }
  recordingBar.classList.add('hidden');
}

cancelRecordingBtn.addEventListener('click', cleanupAudioRecording);

stopAndSendRecordingBtn.addEventListener('click', () => {
  cleanupAudioRecording();
  const chat = conversations.find(c => c.id === activeChatId);
  if (!chat) return;

  const now = new Date();
  const timeStr = now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });

  chat.messages.push({
    id: `vn_${Date.now()}`,
    senderId: currentUser.id,
    sender: 'me',
    audio: './assets/callingtone.mp3',
    time: timeStr,
    status: 'sent'
  });

  saveStoredConversations(conversations);
  renderMessages();
  renderChatList();
  simulateAutomatedContactReply(chat);
});

// Calling Overlay
const audioCallBtn = document.getElementById('audio-call-btn');
const videoCallBtn = document.getElementById('video-call-btn');
const callModal = document.getElementById('call-modal');
const callEndBtn = document.getElementById('call-end-btn');
const callContactName = document.getElementById('call-contact-name');
const callContactAvatar = document.getElementById('call-contact-avatar');
const callStatusLabel = document.getElementById('call-status-label');
const callTimer = document.getElementById('call-timer');
const localVideoPreview = document.getElementById('local-video-preview');
const ringtoneAudio = document.getElementById('ringtone-audio');

audioCallBtn.addEventListener('click', () => startCall(false));
videoCallBtn.addEventListener('click', () => startCall(true));

async function startCall(isVideo) {
  const chat = conversations.find(c => c.id === activeChatId);
  if (!chat) return;

  callContactName.textContent = chat.name;
  callContactAvatar.src = sanitizeUrl(chat.avatar);
  callStatusLabel.textContent = isVideo ? 'Video Calling...' : 'Calling...';
  callModal.classList.remove('hidden');

  try {
    ringtoneAudio.currentTime = 0;
    ringtoneAudio.play().catch(() => {});
  } catch (e) {}

  if (isVideo) {
    try {
      localMediaStream = await navigator.mediaDevices.getUserMedia({ video: true, audio: true });
      localVideoPreview.srcObject = localMediaStream;
      localVideoPreview.classList.remove('hidden');
    } catch (err) {
      console.warn('[Call] Camera access error:', err);
    }
  }

  setTimeout(() => {
    ringtoneAudio.pause();
    callStatusLabel.textContent = 'Connected';
    startCallDurationTimer();
  }, 2500);
}

function startCallDurationTimer() {
  callDuration = 0;
  clearInterval(callTimerInterval);
  callTimerInterval = setInterval(() => {
    callDuration++;
    const m = Math.floor(callDuration / 60);
    const s = callDuration % 60;
    callTimer.textContent = `${m < 10 ? '0' : ''}${m}:${s < 10 ? '0' : ''}${s}`;
  }, 1000);
}

callEndBtn.addEventListener('click', endCall);

function endCall() {
  clearInterval(callTimerInterval);
  ringtoneAudio.pause();
  ringtoneAudio.currentTime = 0;

  if (localMediaStream) {
    localMediaStream.getTracks().forEach(track => track.stop());
    localMediaStream = null;
  }
  localVideoPreview.srcObject = null;
  localVideoPreview.classList.add('hidden');
  callModal.classList.add('hidden');
}

window.addEventListener('beforeunload', () => {
  if (localMediaStream) localMediaStream.getTracks().forEach(t => t.stop());
  if (mediaRecorder && mediaRecorder.stream) mediaRecorder.stream.getTracks().forEach(t => t.stop());
});

// ==========================================
// 14. Stories Modal
// ==========================================
const storyModal = document.getElementById('story-modal');
const closeStoryBtn = document.getElementById('close-story-btn');
const storyUserAvatar = document.getElementById('story-user-avatar');
const storyUserName = document.getElementById('story-user-name');
const storyImg = document.getElementById('story-img');
const storyCaption = document.getElementById('story-caption');
const storyProgressContainer = document.getElementById('story-progress-container');
let storyTimeout = null;

function openStoryModal(story) {
  story.hasUnseen = false;
  renderStories();

  storyUserAvatar.src = sanitizeUrl(story.avatar);
  storyUserName.textContent = story.userName;
  storyImg.src = sanitizeUrl(story.media, './assets/app_icon.png');
  storyCaption.textContent = story.caption || '';

  storyProgressContainer.innerHTML = `
    <div class="h-1 bg-white/40 flex-1 rounded-full overflow-hidden">
      <div class="h-full bg-white transition-all duration-[5000ms] w-0" id="story-progress-fill"></div>
    </div>
  `;

  storyModal.classList.remove('hidden');

  setTimeout(() => {
    const fill = document.getElementById('story-progress-fill');
    if (fill) fill.style.width = '100%';
  }, 50);

  clearTimeout(storyTimeout);
  storyTimeout = setTimeout(() => {
    storyModal.classList.add('hidden');
  }, 5200);
}

closeStoryBtn.addEventListener('click', () => {
  clearTimeout(storyTimeout);
  storyModal.classList.add('hidden');
});

// ==========================================
// 15. Search Filter
// ==========================================
const searchInput = document.getElementById('search-input');
const clearSearchBtn = document.getElementById('clear-search');

searchInput.addEventListener('input', (e) => {
  const val = e.target.value;
  if (val) {
    clearSearchBtn.classList.remove('hidden');
  } else {
    clearSearchBtn.classList.add('hidden');
  }
  renderChatList(val);
});

clearSearchBtn.addEventListener('click', () => {
  searchInput.value = '';
  clearSearchBtn.classList.add('hidden');
  renderChatList('');
});

// ==========================================
// 16. Bootstrap
// ==========================================
initCurrentUser();
conversations = getStoredConversations();
renderStories();
renderChatList();
if (conversations.length > 0) {
  selectChat(conversations[0].id);
}

document.addEventListener('click', () => {
  if ('Notification' in window && Notification.permission === 'default') {
    Notification.requestPermission();
  }
}, { once: true });
