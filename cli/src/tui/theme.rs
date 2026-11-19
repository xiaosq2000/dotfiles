use crate::model::ThemeSpec;
use ratatui::style::Color;

#[derive(Debug, Clone, Copy)]
pub struct TuiTheme {
    pub bg: Color,
    pub surface: Color,
    pub fg: Color,
    pub fg_bright: Color,
    pub border: Color,
    pub primary: Color,
    pub accent: Color,
    pub info: Color,
    pub vcs: Color,
    pub warn: Color,
    pub error: Color,
    pub ok: Color,
}

impl Default for TuiTheme {
    fn default() -> Self {
        // Rosé Pine dark fallback
        Self {
            bg: Color::Rgb(0x19, 0x17, 0x24),
            surface: Color::Rgb(0x26, 0x23, 0x3a),
            fg: Color::Rgb(0x90, 0x8c, 0xaa),
            fg_bright: Color::Rgb(0xe0, 0xde, 0xf4),
            border: Color::Rgb(0x40, 0x3d, 0x52),
            primary: Color::Rgb(0xc4, 0xa7, 0xe7),
            accent: Color::Rgb(0xeb, 0xbc, 0xba),
            info: Color::Rgb(0x31, 0x74, 0x8f),
            vcs: Color::Rgb(0x9c, 0xcf, 0xd8),
            warn: Color::Rgb(0xf6, 0xc1, 0x77),
            error: Color::Rgb(0xeb, 0x6f, 0x92),
            ok: Color::Rgb(0x9c, 0xcf, 0xd8),
        }
    }
}

pub fn parse_hex(s: &str) -> Option<Color> {
    let hex = s.trim().strip_prefix('#')?;
    if hex.len() != 6 {
        return None;
    }
    let r = u8::from_str_radix(&hex[0..2], 16).ok()?;
    let g = u8::from_str_radix(&hex[2..4], 16).ok()?;
    let b = u8::from_str_radix(&hex[4..6], 16).ok()?;
    Some(Color::Rgb(r, g, b))
}

impl TuiTheme {
    pub fn from_spec(spec: &ThemeSpec) -> Self {
        let fb = Self::default();
        let ok = parse_hex(&spec.starship.vcs)
            .or_else(|| parse_hex(&spec.fzf.info))
            .unwrap_or(fb.ok);
        Self {
            bg: parse_hex(&spec.fzf.bg).unwrap_or(fb.bg),
            surface: parse_hex(&spec.fzf.bg_plus)
                .or_else(|| parse_hex(&spec.starship.surface))
                .unwrap_or(fb.surface),
            fg: parse_hex(&spec.fzf.fg).unwrap_or(fb.fg),
            fg_bright: parse_hex(&spec.fzf.fg_plus).unwrap_or(fb.fg_bright),
            border: parse_hex(&spec.fzf.border).unwrap_or(fb.border),
            primary: parse_hex(&spec.starship.primary)
                .or_else(|| parse_hex(&spec.fzf.pointer))
                .unwrap_or(fb.primary),
            accent: parse_hex(&spec.starship.accent)
                .or_else(|| parse_hex(&spec.fzf.hl))
                .unwrap_or(fb.accent),
            info: parse_hex(&spec.starship.lang)
                .or_else(|| parse_hex(&spec.fzf.header))
                .unwrap_or(fb.info),
            vcs: parse_hex(&spec.starship.vcs)
                .or_else(|| parse_hex(&spec.fzf.info))
                .unwrap_or(fb.vcs),
            warn: parse_hex(&spec.starship.warn)
                .or_else(|| parse_hex(&spec.fzf.spinner))
                .unwrap_or(fb.warn),
            error: parse_hex(&spec.starship.error)
                .or_else(|| parse_hex(&spec.fzf.marker))
                .unwrap_or(fb.error),
            ok,
        }
    }
}
