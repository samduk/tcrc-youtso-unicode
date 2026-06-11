TCRC Youtso Unicode - Windows 11 test
========================================

This folder is for the Windows 11 VMware machine.

Automated test
--------------
1. Open:
   \\vmware-host\Shared Folders\share\TCRC-Windows-Release
2. Double-click Run-Windows-Test.cmd.
3. Approve the administrator prompt.
4. Confirm every line reports PASS.

The test verifies:
- silent installation;
- font and keyboard registration;
- desktop and Start menu converter shortcuts;
- .doc and .docx right-click commands;
- no Microsoft Himalaya font replacement;
- preservation of the original document;
- conversion of a generated legacy test document to expected Unicode Tibetan;
- opening the Unicode result in Microsoft Word;
- Tibetan number display and numeric calculation in Microsoft Excel;
- startup of the visible converter window.

Manual check
------------
1. Open TCRC Document Converter from the desktop.
2. Choose a copy of a legacy TCRC Word document.
3. Select Convert to Unicode.
4. Confirm the Unicode copy opens correctly.
5. Confirm the original document still exists and was not modified.
6. Start Tibetan Keyboard and test Ctrl+Alt+T in Word.
7. Open Excel and select A1:A3.
8. Press Ctrl+Alt+N and enter 125 in A1 and 75 in A2.
9. Use SUM in A3 and confirm the result is 200 in Tibetan-looking digits.
