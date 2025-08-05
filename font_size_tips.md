# Making Text Bigger in i_speaker Presentations

Since i_speaker runs in the terminal, the actual font size is controlled by your terminal emulator settings, not the Ruby code. Here are several ways to make the text appear bigger:

## 1. Terminal Font Size (Recommended)

The simplest solution is to increase your terminal's font size before presenting:

### macOS Terminal.app
- Press `Cmd + Plus` to increase font size
- Press `Cmd + Minus` to decrease font size
- Or go to Terminal → Preferences → Profiles → Text → Font

### iTerm2
- Press `Cmd + Plus` to increase font size
- Press `Cmd + Minus` to decrease font size
- Or go to iTerm2 → Preferences → Profiles → Text

### VS Code Terminal
- Press `Cmd + Plus` (Mac) or `Ctrl + Plus` (Windows/Linux)
- Or add to settings.json: `"terminal.integrated.fontSize": 18`

### Other Terminals
- Alacritty: Edit `~/.config/alacritty/alacritty.yml` and increase `font.size`
- Kitty: Press `Ctrl+Shift+Plus` or edit `~/.config/kitty/kitty.conf`
- Windows Terminal: Press `Ctrl + Plus` or edit settings

## 2. Presentation Mode

Many terminals have a "presentation mode" or you can create a profile specifically for presentations with larger fonts:

```bash
# Example: Create an alias for presentation mode
alias present='echo -e "\033]50;SetProfile=Presentation\a"'
```

## 3. ASCII Art Enhancement (Already Added)

I've added ASCII art support for important slides. The following slides will now display with large ASCII art titles when your terminal width is > 100 characters:

- Welcome slides (first slide)
- Demo slides (titles containing "DEMO")
- Q&A slides
- Thank you slides (last slide)

## 4. Terminal Zoom

Some modern terminals support zooming the entire interface:

- **macOS**: Use the system zoom with `Ctrl + Scroll` or `Cmd + Option + =`
- **Linux**: Many terminals support `Ctrl + Shift + Plus`

## 5. External Display Recommendations

When presenting on a projector or external display:

1. **Lower Resolution**: Set your display to 1920x1080 instead of 4K
2. **Mirror Display**: This often results in larger text
3. **Use a High Contrast Theme**: The default green-on-black is good

## Usage Tips

1. **Test Before Presenting**: Always test your font size with the actual projector
2. **Sit in the Back**: Check readability from the back of the room
3. **Use Shorter Content**: I've already simplified your slides to have fewer bullet points
4. **High Contrast**: The green titles and white text provide good contrast

## Quick Setup for Presentations

```bash
# 1. Increase terminal font to 18-24pt
# 2. Set terminal to fullscreen (Cmd+Enter on Mac)
# 3. Run your presentation
exe/i_speaker

# 4. Use these navigation keys:
# SPACE or → : Next slide
# ← : Previous slide  
# P : Pause timer
# C : Toggle AI commentary
# ESC : Exit
```

The text enhancements I've made:
- ✅ Simplified slides with fewer bullet points
- ✅ Split long code blocks into separate slides
- ✅ Added ASCII art for important slide titles
- ✅ Made bullet points more prominent with ▸ symbol
- ✅ Bold text for better visibility

Remember: The most effective way to ensure readability is to increase your terminal's font size to 18-24pt before presenting!