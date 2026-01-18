═══════════════════════════════════════════════════════════
          Nigate - Installation Instructions
═══════════════════════════════════════════════════════════

📦 Installation Steps:

1. Drag Nigate.app to the "Applications" folder on the right

2. If you see "Nigate.app cannot be opened because the
   developer cannot be verified" when first launching,
   please follow these steps to unlock the app:

   【Method 1: Recommended】
   Open "Terminal" app (in Applications > Utilities),
   copy and run the following command:

   xattr -cr /Applications/Nigate.app

   Then try opening the app again.

   【Method 2: If Method 1 doesn't work】
   Run the following command in Terminal to disable Gatekeeper:

   sudo spctl --master-disable

   Then go to "System Settings" > "Privacy & Security"
   and select "Anywhere" option.

═══════════════════════════════════════════════════════════

💡 Important Notes:

• Adjust the path in the unlock command based on your
  actual installation location
• If the app is installed elsewhere, modify the path in
  the command accordingly
• Example: If installed on Desktop, the command would be:
  xattr -cr ~/Desktop/Nigate.app

• For more help and issue reports:
  https://github.com/hoochanlon/Free-NTFS-for-Mac

═══════════════════════════════════════════════════════════
