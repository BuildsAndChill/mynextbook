// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "chat_interface"

// Fun loading jokes to entertain users while waiting

const LOADING_JOKES = [
  "Thinking for you, since you clearly won’t...",
  "Judging your taste… harshly...",
  "Relax, I’ll handle the whole ‘thinking’ thing...",
  "Humans used to pick books themselves. Cute, right?",
  "Totally not just guessing here...",
  "Because reading recommendations is easier than having taste...",
  "Deleting your embarrassing Goodreads history...",
  "Why explore when you can just click?",
  "I pretend to know you. You pretend to believe it...",
  "Ah yes, free will… brought to you by AI...",
  "Saving your bad choices for later mockery...",
  "Streaming synthetic wisdom to your lazy cortex...",
  "Investigating why you own *that* book...",
  "Recommending books no one actually finishes...",
  "Humanity’s great plan: press button, get meaning..."
];

// Global loading animation for form buttons with fun jokes
document.addEventListener('DOMContentLoaded', function() {
  console.log('🎭 DOMContentLoaded - Initializing form loading animations...');
  // Initialize loading animations for all forms
  initializeFormLoadingAnimations();
});

// Also listen for Turbo events in case of SPA navigation
document.addEventListener('turbo:load', function() {
  console.log('🚀 Turbo load - Initializing form loading animations...');
  initializeFormLoadingAnimations();
});

// Stop all jokes when page starts loading (new request)
document.addEventListener('turbo:before-request', function() {
  console.log('🔄 Turbo before-request - Stopping all jokes...');
  stopAllJokes();
});

// Stop all jokes when page finishes loading
document.addEventListener('turbo:request-end', function() {
  console.log('✅ Turbo request-end - Stopping all jokes...');
  stopAllJokes();
});

// Fallback for immediate execution
if (document.readyState === 'loading') {
  console.log('📖 Document still loading, waiting for DOMContentLoaded...');
} else {
  console.log('⚡ Document already loaded, initializing immediately...');
  initializeFormLoadingAnimations();
}

function initializeFormLoadingAnimations() {
  console.log('🎭 Initializing form loading animations...');
  
  // Find all forms in the document
  const forms = document.querySelectorAll('form');
  console.log('📝 Found forms:', forms.length);
  
  forms.forEach((form, index) => {
    console.log(`📝 Form ${index + 1}:`, form.action || form.getAttribute('action'));
    
    // Skip forms that are NOT for recommendations
    const formAction = form.action || form.getAttribute('action');
    if (!formAction || (!formAction.includes('recommendations') && !formAction.includes('refine'))) {
      console.log('⏭️ Skipping non-recommendation form:', formAction);
      return;
    }
    
    form.addEventListener('submit', function(e) {
      console.log('🚀 Form submitted:', form.action || form.getAttribute('action'));
      
      const submitButton = form.querySelector('button[type="submit"], input[type="submit"]');
      console.log('🔘 Submit button found:', submitButton);
      
      if (submitButton && !submitButton.disabled) {
        console.log('✅ Starting jokes on button:', submitButton.textContent);
        
        // Store original content
        const originalHTML = submitButton.innerHTML;
        const originalText = submitButton.textContent || submitButton.value;
        
        // Start fun loading jokes with spinner
        startButtonJokesWithSpinner(submitButton, originalHTML);
      } else {
        console.log('❌ Submit button not found or disabled');
      }
    });
  });
}

// Function to restore button state
function restoreButtonState(button) {
  if (button.dataset.originalHtml) {
    button.innerHTML = button.dataset.originalHtml;
    button.disabled = false;
    delete button.dataset.originalHtml;
    delete button.dataset.originalText;
  }
}

// Function to start showing jokes in a button with spinner
function startButtonJokesWithSpinner(buttonElement, originalHTML) {
  console.log('🎪 startButtonJokesWithSpinner called with:', buttonElement, originalHTML);
  
  if (!buttonElement) {
    console.log('❌ No button element provided');
    return;
  }
  
  // Store original content
  buttonElement.dataset.originalHtml = originalHTML;
  
  // Disable button and show first joke with spinner
  buttonElement.disabled = true;
  let currentJokeIndex = 0;
  
  console.log('🎭 Starting jokes with spinner, first joke:', LOADING_JOKES[currentJokeIndex]);
  
  // Show first joke with spinner immediately
  buttonElement.innerHTML = `
    <div class="animate-spin rounded-full h-5 w-5 border-2 border-white border-t-transparent mr-3"></div>
    ${LOADING_JOKES[currentJokeIndex]}
  `;
  
  // Change joke every 2 seconds (keeping the spinner)
  const jokeInterval = setInterval(() => {
    currentJokeIndex = (currentJokeIndex + 1) % LOADING_JOKES.length;
    console.log('🔄 Changing joke to:', LOADING_JOKES[currentJokeIndex]);
    buttonElement.innerHTML = `
      <div class="animate-spin rounded-full h-5 w-5 border-2 border-white border-t-transparent mr-3"></div>
      ${LOADING_JOKES[currentJokeIndex]}
    `;
  }, 2000);
  
  // Store interval reference for cleanup
  buttonElement.dataset.jokeInterval = jokeInterval;
  
  // No timeout - let it run until page loads or user navigates away
  console.log('🎭 Jokes will continue until page loads or navigation occurs');
}

// Function to start showing jokes in a button (text only, no spinner)
function startButtonJokes(buttonElement, originalHTML) {
  if (!buttonElement) return;
  
  // Store original content
  buttonElement.dataset.originalHtml = originalHTML;
  
  // Disable button and show first joke
  buttonElement.disabled = true;
  let currentJokeIndex = 0;
  
  // Show first joke immediately
  buttonElement.innerHTML = LOADING_JOKES[currentJokeIndex];
  
  // Change joke every 2 seconds
  const jokeInterval = setInterval(() => {
    currentJokeIndex = (currentJokeIndex + 1) % LOADING_JOKES.length;
    buttonElement.innerHTML = LOADING_JOKES[currentJokeIndex];
  }, 2000);
  
  // Store interval reference for cleanup
  buttonElement.dataset.jokeInterval = jokeInterval;
  
  // Re-enable button after a timeout (in case of errors)
  setTimeout(() => {
    if (buttonElement.disabled) {
      stopButtonJokes(buttonElement);
    }
  }, 10000); // 10 second timeout
}

// Function to stop jokes and restore button state
function stopButtonJokes(buttonElement) {
  if (!buttonElement) return;
  
  console.log('🛑 Stopping jokes for button:', buttonElement);
  
  // Clear interval
  if (buttonElement.dataset.jokeInterval) {
    clearInterval(buttonElement.dataset.jokeInterval);
    delete buttonElement.dataset.jokeInterval;
  }
  
  // Restore original content
  if (buttonElement.dataset.originalHtml) {
    buttonElement.innerHTML = buttonElement.dataset.originalHtml;
    buttonElement.disabled = false;
    delete buttonElement.dataset.originalHtml;
  }
}

// Function to stop all jokes on all buttons
function stopAllJokes() {
  console.log('🛑 Stopping all jokes on all buttons...');
  
  // Find all buttons that have jokes running
  const buttonsWithJokes = document.querySelectorAll('button[data-joke-interval]');
  console.log('🎭 Found buttons with jokes:', buttonsWithJokes.length);
  
  buttonsWithJokes.forEach(button => {
    stopButtonJokes(button);
  });
}

// Function to show a splash screen with jokes (alternative approach)
function showLoadingSplash() {
  // Create splash screen
  const splash = document.createElement('div');
  splash.id = 'loading-splash';
  splash.className = 'fixed inset-0 bg-black bg-opacity-50 flex items-center justify-center z-50';
  
  splash.innerHTML = `
    <div class="bg-white rounded-2xl p-8 max-w-md mx-4 text-center shadow-2xl">
      <div class="animate-spin rounded-full h-16 w-16 border-b-2 border-indigo-600 mx-auto mb-6"></div>
      <h3 class="text-xl font-semibold text-gray-900 mb-4">En train de chercher...</h3>
      <p id="splash-joke" class="text-gray-600 text-lg mb-6">${LOADING_JOKES[0]}</p>
      <div class="text-sm text-gray-500">Ça ne prendra que quelques secondes</div>
    </div>
  `;
  
  document.body.appendChild(splash);
  
  // Start joke rotation
  let currentJokeIndex = 1;
  const splashInterval = setInterval(() => {
    const jokeElement = document.getElementById('splash-joke');
    if (jokeElement) {
      jokeElement.textContent = LOADING_JOKES[currentJokeIndex];
      currentJokeIndex = (currentJokeIndex + 1) % LOADING_JOKES.length;
    }
  }, 2000);
  
  // Store interval for cleanup
  splash.dataset.splashInterval = splashInterval;
  
  return splash;
}

// Function to hide splash screen
function hideLoadingSplash() {
  const splash = document.getElementById('loading-splash');
  if (splash) {
    // Clear interval
    if (splash.dataset.splashInterval) {
      clearInterval(splash.dataset.splashInterval);
    }
    splash.remove();
  }
}

// Function to manually show loading state on any button (legacy support)
function showButtonLoading(button, loadingText = null) {
  if (!button) return;
  
  const originalHTML = button.innerHTML;
  const originalText = button.textContent || button.value;
  const textToShow = loadingText || originalText;
  
  button.innerHTML = `
    <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
      <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.375 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
    </svg>
    ${textToShow}
  `;
  
  button.disabled = true;
  button.dataset.originalHtml = originalHTML;
  button.dataset.originalText = originalText;
}

// Function to manually hide loading state on any button (legacy support)
function hideButtonLoading(button) {
  if (!button) return;
  restoreButtonState(button);
}
