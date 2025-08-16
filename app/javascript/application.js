// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "chat_interface"

// Global loading animation for form buttons
document.addEventListener('DOMContentLoaded', function() {
  // Initialize loading animations for all forms
  initializeFormLoadingAnimations();
});

function initializeFormLoadingAnimations() {
  // Find all forms in the document
  const forms = document.querySelectorAll('form');
  
  forms.forEach(form => {
    form.addEventListener('submit', function(e) {
      const submitButton = form.querySelector('button[type="submit"], input[type="submit"]');
      
      if (submitButton && !submitButton.disabled) {
        // Store original content
        const originalHTML = submitButton.innerHTML;
        const originalText = submitButton.textContent || submitButton.value;
        
        // Show loading state
        submitButton.innerHTML = `
          <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
          ${originalText}
        `;
        
        // Disable button
        submitButton.disabled = true;
        
        // Store original content and button reference for restoration
        submitButton.dataset.originalHtml = originalHTML;
        submitButton.dataset.originalText = originalText;
        
        // Re-enable button after a timeout (in case of errors)
        setTimeout(() => {
          if (submitButton.disabled) {
            restoreButtonState(submitButton);
          }
        }, 10000); // 10 second timeout
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

// Function to manually show loading state on any button
function showButtonLoading(button, loadingText = null) {
  if (!button) return;
  
  const originalHTML = button.innerHTML;
  const originalText = button.textContent || button.value;
  const textToShow = loadingText || originalText;
  
  button.innerHTML = `
    <svg class="animate-spin -ml-1 mr-3 h-5 w-5 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
      <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
      <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
    </svg>
    ${textToShow}
  `;
  
  button.disabled = true;
  button.dataset.originalHtml = originalHTML;
  button.dataset.originalText = originalText;
}

// Function to manually hide loading state on any button
function hideButtonLoading(button) {
  if (!button) return;
  restoreButtonState(button);
}
