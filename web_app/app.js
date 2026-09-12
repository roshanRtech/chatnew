/**
 * Mighty Chat Progressive Web App (PWA)
 * Core Controller & Reactive State
 */

// ==========================================
// 1. PWA Service Worker & Install Management
// ==========================================
let deferredPrompt = null;

if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => {
    navigator.serviceWorker.register('./sw.js')
      .then((reg) => {
        console.log('[PWA] Service Worker registered with scope:', reg.scope);
      })
      .catch((err) => {
        console.warn('[PWA] Service Worker registration failed:', err);
      });
  });
}

// Handle Install Prompt
window.addEventListener('beforeinstallprompt', (e) => {
  e.preventDefault();
  deferredPrompt = e;
  const installBanner = document.getElementById('pwa-install-banner');
  if (installBanner) installBanner.classList.remove('hidden');
});

window.addEventListener('appinstalled', () => {
  deferredPrompt = null;
  const installBanner = document.getElementById('pwa-install-banner');
  if (installBanner) installBanner.classList.add('hidden');
  console.log('[PWA] App installed successfully');
});

const pwaInstallBtn = document.getElementById('pwa-install-btn');
const headerInstallBtn = document.getElementById('header-install-btn');
const pwaDismissBtn = document.getElementById('pwa-dismiss-btn');

function triggerInstall() {
  if (deferredPrompt) {
    deferredPrompt.prompt();
    deferredPrompt.userChoice.then((choice) => {
      if (choice.outcome === 'accepted') {
        console.log('[PWA] User accepted installation prompt');
      }
      deferredPrompt = null;
    });
  } else {
    alert('To install Mighty Chat PWA:\n• Chrome/Edge: Click the Install icon in the address bar.\n• Safari (iOS): Tap "Share" -> "Add to Home Screen".');
  }
}

if (pwaInstallBtn) pwaInstallBtn.addEventListener('click', triggerInstall);
if (headerInstallBtn) headerInstallBtn.addEventListener('click', triggerInstall);
if (pwaDismissBtn) {
  pwaDismissBtn.addEventListener('click', () => {
    document.getElementById('pwa-install-banner').classList.add('hidden');
  });
}

// ==========================================
// 2. Online / Offline Connectivity Detection
// ==========================================
const offlineBanner = document.getElementById('offline-banner');

function updateOnlineStatus() {
  if (navigator.onLine) {
    offlineBanner.classList.add('hidden');
  } else {
    offlineBanner.classList.remove('hidden');
  }
}
window.addEventListener('online', updateOnlineStatus);
window.addEventListener('offline', updateOnlineStatus);
updateOnlineStatus();

// ==========================================
// 3. Dark / Light Theme Management
// ==========================================
const themeToggleBtn = document.getElementById('theme-toggle-btn');
const themeIconSun = document.getElementById('theme-icon-sun');
const themeIconMoon = document.getElementById('theme-icon-moon');

function initTheme() {
  const savedTheme = localStorage.getItem('mighty_theme') || 'dark';
  if (savedTheme === 'dark') {
    document.documentElement.classList.add('dark');
    themeIconSun.classList.remove('hidden');
    themeIconMoon.classList.add('hidden');
  } else {
    document.documentElement.classList.remove('dark');
    themeIconSun.classList.add('hidden');
    themeIconMoon.classList.remove('hidden');
  }
}

themeToggleBtn.addEventListener('click', () => {
  const isDark = document.documentElement.classList.toggle('dark');
  localStorage.setItem('mighty_theme', isDark ? 'dark' : 'light');
  if (isDark) {
    themeIconSun.classList.remove('hidden');
    themeIconMoon.classList.add('hidden');
  } else {
    themeIconSun.classList.add('hidden');
    themeIconMoon.classList.remove('hidden');
  }
});
initTheme();

// ==========================================
// 4. Initial State & Realistic Data
// ==========================================
const currentUser = {
  id: 'user_me',
  name: 'John Doe',
  avatar: './assets/user.png',
  status: 'Online'
};

const storiesData = [
  {
    id: 's0',
    userName: 'My Status',
    avatar: './assets/user.png',
    isMe: true,
    hasUnseen: false,
    media: './assets/app_icon.png',
    caption: 'Tap + to share an update'
  },
  {
    id: 's1',
    userName: 'Sarah',
    avatar: './assets/user.png',
    hasUnseen: true,
    media: './assets/group_user.jpg',
    caption: 'Team lunch before launching the new Flutter & PWA release! 🚀'
  },
  {
    id: 's2',
    userName: 'Mobile Team',
    avatar: './assets/group_user.jpg',
    hasUnseen: true,
    media: './assets/default_wallpaper_dark.jpg',
    caption: 'Clean dark UI testing session 💻'
  },
  {
    id: 's3',
    userName: 'Alex R.',
    avatar: './assets/user.png',
    hasUnseen: true,
    media: './assets/app_icon.png',
    caption: 'Server latency down to 24ms! 🔥'
  }
];

let conversations = [
  {
    id: 'c1',
    name: 'Sarah Connor',
    avatar: './assets/user.png',
    isGroup: false,
    online: true,
    lastSeen: 'online',
    unreadCount: 2,
    messages: [
      { id: 'm1', sender: 'them', text: 'Hey John! Have you seen the latest PWA updates?', time: '10:15 AM', status: 'read' },
      { id: 'm2', sender: 'me', text: 'Yes, just testing the offline service worker and push notifications right now.', time: '10:16 AM', status: 'read' },
      { id: 'm3', sender: 'them', text: 'Awesome! Does voice recording and video call work seamlessly too?', time: '10:18 AM', status: 'delivered' },
      { id: 'm4', sender: 'them', text: 'Let me know once you test the audio call.', time: '10:19 AM', status: 'delivered' }
    ]
  },
  {
    id: 'c2',
    name: 'Mobile Engineering Team',
    avatar: './assets/group_user.jpg',
    isGroup: true,
    online: true,
    lastSeen: '12 members active',
    unreadCount: 0,
    messages: [
      { id: 'gm1', sender: 'them', senderName: 'Alex Rivera', text: 'We just pushed the latest Firebase rules and Firestore indexes.', time: '09:30 AM', status: 'read' },
      { id: 'gm2', sender: 'them', senderName: 'Emily Watson', text: 'UI components look crisp in both dark and light modes!', time: '09:42 AM', status: 'read' },
      { id: 'gm3', sender: 'me', text: 'Great work everyone! App is super responsive.', time: '09:45 AM', status: 'read' }
    ]
  },
  {
    id: 'c3',
    name: 'David Miller (Product)',
    avatar: './assets/user.png',
    isGroup: false,
    online: false,
    lastSeen: 'Last seen today at 08:45 AM',
    unreadCount: 0,
    messages: [
      { id: 'dm1', sender: 'them', text: 'Hey John, client approved the demo mockup.', time: 'Yesterday', status: 'read' },
      { id: 'dm2', sender: 'me', text: 'Perfect. We can finalize the deployment checklist today.', time: 'Yesterday', status: 'read' }
    ]
  },
  {
    id: 'c4',
    name: 'Emily Watson',
    avatar: './assets/user.png',
    isGroup: false,
    online: true,
    lastSeen: 'online',
    unreadCount: 0,
    messages: [
      { id: 'ew1', sender: 'them', text: 'Sent you the new icons for the home screen shortcut.', time: 'Sep 10', status: 'read' }
    ]
  }
];

let activeChatId = 'c1';
let activePendingAttachment = null;
let mediaRecorder = null;
let audioChunks = [];
let recordingInterval = null;
let recordingSeconds = 0;

// ==========================================
// 5. Render Stories
// ==========================================
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

    item.innerHTML = `
      <div class="${ringClass} transition transform group-hover:scale-105">
        <div class="p-0.5 bg-white dark:bg-dark-panel rounded-full">
          <img src="${story.avatar}" class="w-12 h-12 rounded-full object-cover" alt="${story.userName}">
        </div>
      </div>
      <span class="text-[11px] text-gray-700 dark:text-gray-300 truncate max-w-[64px] mt-1 font-medium">${story.userName}</span>
    `;

    item.addEventListener('click', () => openStoryModal(story));
    container.appendChild(item);
  });
}

// ==========================================
// 6. Render Conversation List
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
    chatList.innerHTML = `
      <div class="p-8 text-center text-gray-400 text-xs">
        No chats found matching "${filterQuery}"
      </div>
    `;
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
        <img src="${chat.avatar}" class="w-12 h-12 rounded-full object-cover border border-gray-200 dark:border-gray-700" alt="${chat.name}">
        ${chat.online ? '<span class="absolute bottom-0 right-0 w-3 h-3 bg-emerald-500 border-2 border-white dark:border-dark-panel rounded-full"></span>' : ''}
      </div>
      <div class="flex-1 min-w-0">
        <div class="flex items-center justify-between">
          <h4 class="text-sm font-semibold text-gray-900 dark:text-gray-100 truncate">${chat.name}</h4>
          <span class="text-[11px] text-gray-400 font-medium">${lastMsg.time || ''}</span>
        </div>
        <div class="flex items-center justify-between mt-1">
          <p class="text-xs text-gray-500 dark:text-gray-400 truncate flex items-center pr-2">
            ${statusCheckmarks}
            <span class="truncate">${lastMsg.image ? '📷 Photo' : (lastMsg.audio ? '🎵 Voice Note' : (lastMsg.text || ''))}</span>
          </p>
          ${chat.unreadCount > 0 ? `
            <span class="bg-brand-600 text-white text-[10px] font-bold rounded-full h-5 min-w-[20px] px-1.5 flex items-center justify-center shadow-sm">
              ${chat.unreadCount}
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
  activeChatId = chatId;
  const chat = conversations.find(c => c.id === chatId);
  if (!chat) return;

  // Clear unread
  chat.unreadCount = 0;

  // Mobile layout switch
  const sidebar = document.getElementById('sidebar');
  const chatWindow = document.getElementById('chat-window');
  const noChatSelected = document.getElementById('no-chat-selected');
  const activeChatContainer = document.getElementById('active-chat-container');

  sidebar.classList.add('hidden', 'md:flex');
  chatWindow.classList.remove('hidden');
  noChatSelected.classList.add('hidden');
  activeChatContainer.classList.remove('hidden');

  // Update Header
  document.getElementById('chat-header-avatar').src = chat.avatar;
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

// Back to list on mobile
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

  // Date banner
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

    let bubbleBg = isMe 
      ? 'bg-brand-600 text-white rounded-br-none shadow-sm' 
      : 'bg-white dark:bg-dark-card text-gray-900 dark:text-gray-100 rounded-bl-none shadow-sm border border-gray-100 dark:border-dark-border/40';

    let contentHtml = '';

    // Image Message
    if (msg.image) {
      contentHtml += `
        <div class="mb-1.5 overflow-hidden rounded-xl cursor-pointer">
          <img src="${msg.image}" class="max-w-[260px] md:max-w-[320px] max-h-64 object-cover hover:opacity-95 transition" alt="Attachment">
        </div>
      `;
    }

    // Audio / Voice Note Message
    if (msg.audio) {
      contentHtml += `
        <div class="flex items-center space-x-3 py-1">
          <button onclick="playVoiceNote('${msg.id}', '${msg.audio}')" id="play-btn-${msg.id}" class="p-2 rounded-full ${isMe ? 'bg-white text-brand-700' : 'bg-brand-600 text-white'} shadow">
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
              <span class="w-1 h-5 bg-current opacity-90 rounded-full"></span>
            </div>
            <span class="text-[10px] opacity-80">0:14</span>
          </div>
        </div>
      `;
    }

    // Text Message
    if (msg.text) {
      contentHtml += `<p class="text-sm whitespace-pre-wrap leading-relaxed">${escapeHtml(msg.text)}</p>`;
    }

    // Group sender name
    const senderHeader = (!isMe && chat.isGroup && msg.senderName) 
      ? `<div class="text-[11px] font-bold text-amber-500 mb-0.5">${msg.senderName}</div>` 
      : '';

    // Status checkmarks
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
          <span>${msg.time}</span>
          ${statusIcon}
        </div>
      </div>
    `;

    container.appendChild(row);
  });

  // Scroll to bottom
  container.scrollTop = container.scrollHeight;
}

function escapeHtml(text) {
  const map = { '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#039;' };
  return text.replace(/[&<>"']/g, (m) => map[m]);
}

// ==========================================
// 9. Send Message & Typing Simulation
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

  // Auto-resize
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
    id: `m_${Date.now()}`,
    sender: 'me',
    text: text,
    image: activePendingAttachment ? activePendingAttachment.dataUrl : null,
    time: timeStr,
    status: 'sent'
  };

  chat.messages.push(newMsg);

  // Clear inputs
  messageInput.value = '';
  messageInput.style.height = 'auto';
  clearAttachment();
  sendBtn.classList.add('hidden');
  voiceRecordBtn.classList.remove('hidden');

  renderMessages();
  renderChatList();

  // Simulate delivery & read
  setTimeout(() => {
    newMsg.status = 'delivered';
    renderMessages();
  }, 600);

  setTimeout(() => {
    newMsg.status = 'read';
    renderMessages();
  }, 1200);

  // Trigger simulated smart reply
  simulateContactReply(chat);
}

function simulateContactReply(chat) {
  const subtitle = document.getElementById('chat-header-subtitle');
  if (chat.id === activeChatId && subtitle) {
    subtitle.textContent = 'typing...';
    subtitle.className = 'text-xs text-brand-600 dark:text-brand-400 font-semibold animate-pulse';
  }

  setTimeout(() => {
    const replies = [
      "Sounds like a plan! Let's ship it.",
      "Got your update, checking on it now.",
      "Looks great on mobile and desktop!",
      "I love how fast this PWA loads offline.",
      "Everything looks tested and verified 👍",
      "Ready for deployment whenever you are!"
    ];
    const replyText = replies[Math.floor(Math.random() * replies.length)];
    const now = new Date();
    const timeStr = now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });

    chat.messages.push({
      id: `reply_${Date.now()}`,
      sender: 'them',
      text: replyText,
      time: timeStr,
      status: 'read'
    });

    if (chat.id === activeChatId && subtitle) {
      subtitle.textContent = 'online';
      subtitle.className = 'text-xs text-emerald-600 dark:text-emerald-400 font-medium';
    }

    renderMessages();
    renderChatList();

    // Trigger Notification if supported
    if ('Notification' in window && Notification.permission === 'granted') {
      new Notification(`Mighty Chat: ${chat.name}`, {
        body: replyText,
        icon: './icons/icon-192.png'
      });
    }
  }, 2200);
}

// ==========================================
// 10. Attachment Handling
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

// ==========================================
// 11. Voice Note Recording (Web MediaRecorder)
// ==========================================
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
    console.warn('[Audio] Mic access denied or not supported, using mock voice note:', err);
    // Simulate recording if mic permission isn't available
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

cancelRecordingBtn.addEventListener('click', () => {
  clearInterval(recordingInterval);
  if (mediaRecorder && mediaRecorder.state !== 'inactive') {
    mediaRecorder.stop();
  }
  recordingBar.classList.add('hidden');
});

stopAndSendRecordingBtn.addEventListener('click', () => {
  clearInterval(recordingInterval);
  if (mediaRecorder && mediaRecorder.state !== 'inactive') {
    mediaRecorder.stop();
  }
  recordingBar.classList.add('hidden');

  const chat = conversations.find(c => c.id === activeChatId);
  if (!chat) return;

  const now = new Date();
  const timeStr = now.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });

  chat.messages.push({
    id: `vn_${Date.now()}`,
    sender: 'me',
    audio: './assets/callingtone.mp3', // Fallback audio sample
    time: timeStr,
    status: 'sent'
  });

  renderMessages();
  renderChatList();
  simulateContactReply(chat);
});

window.playVoiceNote = function(id, src) {
  const audio = new Audio(src);
  audio.play();
};

// ==========================================
// 12. Audio & Video Call Simulation (WebRTC)
// ==========================================
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

let callTimerInterval = null;
let callDuration = 0;
let localMediaStream = null;

audioCallBtn.addEventListener('click', () => startCall(false));
videoCallBtn.addEventListener('click', () => startCall(true));

async function startCall(isVideo) {
  const chat = conversations.find(c => c.id === activeChatId);
  if (!chat) return;

  callContactName.textContent = chat.name;
  callContactAvatar.src = chat.avatar;
  callStatusLabel.textContent = isVideo ? 'Video Calling...' : 'Calling...';
  callModal.classList.remove('hidden');

  // Play real calling tone
  try {
    ringtoneAudio.currentTime = 0;
    ringtoneAudio.play().catch(() => {});
  } catch (e) {}

  // Request real camera/mic if video call
  if (isVideo) {
    try {
      localMediaStream = await navigator.mediaDevices.getUserMedia({ video: true, audio: true });
      localVideoPreview.srcObject = localMediaStream;
      localVideoPreview.classList.remove('hidden');
    } catch (err) {
      console.warn('[Call] Camera access error:', err);
    }
  }

  // Answered after 3 seconds
  setTimeout(() => {
    ringtoneAudio.pause();
    callStatusLabel.textContent = isVideo ? 'Video Call Connected' : 'Connected';
    startCallDurationTimer();
  }, 3000);
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
  localVideoPreview.classList.add('hidden');
  callModal.classList.add('hidden');
}

// ==========================================
// 13. Story / Status Modal
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

  storyUserAvatar.src = story.avatar;
  storyUserName.textContent = story.userName;
  storyImg.src = story.media;
  storyCaption.textContent = story.caption || '';

  // Progress Bar
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
// 14. Firebase Modal Configuration
// ==========================================
const firebaseBtn = document.getElementById('firebase-btn');
const firebaseModal = document.getElementById('firebase-modal');
const closeFirebaseBtn = document.getElementById('close-firebase-btn');
const saveFirebaseBtn = document.getElementById('save-firebase-btn');
const clearFirebaseBtn = document.getElementById('clear-firebase-btn');
const firebaseConfigJson = document.getElementById('firebase-config-json');

firebaseBtn.addEventListener('click', () => {
  const saved = localStorage.getItem('mighty_firebase_config') || '';
  firebaseConfigJson.value = saved;
  firebaseModal.classList.remove('hidden');
});

closeFirebaseBtn.addEventListener('click', () => {
  firebaseModal.classList.add('hidden');
});

clearFirebaseBtn.addEventListener('click', () => {
  localStorage.removeItem('mighty_firebase_config');
  firebaseConfigJson.value = '';
  alert('Firebase configuration cleared. Running in local PWA mode.');
});

saveFirebaseBtn.addEventListener('click', () => {
  const val = firebaseConfigJson.value.trim();
  if (val) {
    try {
      JSON.parse(val);
      localStorage.setItem('mighty_firebase_config', val);
      alert('Firebase configuration saved successfully! Cloud sync ready.');
      firebaseModal.classList.add('hidden');
    } catch (e) {
      alert('Invalid JSON configuration. Please ensure you paste valid Firebase config JSON.');
    }
  } else {
    firebaseModal.classList.add('hidden');
  }
});

// ==========================================
// 15. Search Filter Live Event
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
renderStories();
renderChatList();
selectChat('c1');

// Request Notification Permission on first user interaction
document.addEventListener('click', () => {
  if ('Notification' in window && Notification.permission === 'default') {
    Notification.requestPermission();
  }
}, { once: true });
