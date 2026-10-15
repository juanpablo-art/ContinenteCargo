import type { Config } from 'tailwindcss';

export default {
  content: ['./index.html', './src/**/*.{vue,js,ts,jsx,tsx}'],
  theme: {
    extend: {
      fontFamily: {
        sans: ['"DM Sans"', 'system-ui', 'sans-serif'],
        display: ['"Source Serif 4"', 'Georgia', 'serif'],
      },
      colors: {
        border: 'rgb(var(--border) / <alpha-value>)',
        input: 'rgb(var(--input) / <alpha-value>)',
        ring: 'rgb(var(--ring) / <alpha-value>)',
        background: 'rgb(var(--background) / <alpha-value>)',
        foreground: 'rgb(var(--foreground) / <alpha-value>)',
        primary: {
          DEFAULT: 'rgb(var(--primary) / <alpha-value>)',
          foreground: 'rgb(var(--primary-foreground) / <alpha-value>)',
        },
        card: {
          DEFAULT: 'rgb(var(--card) / <alpha-value>)',
          foreground: 'rgb(var(--card-foreground) / <alpha-value>)',
        },
        muted: {
          DEFAULT: 'rgb(var(--muted) / <alpha-value>)',
        },
        navy: {
          DEFAULT: 'rgb(var(--navy) / <alpha-value>)',
          soft: 'rgb(var(--navy-soft) / <alpha-value>)',
          deep: 'rgb(var(--navy-deep) / <alpha-value>)',
        },
        brand: 'rgb(var(--brand) / <alpha-value>)',
        blue: {
          DEFAULT: 'rgb(var(--blue) / <alpha-value>)',
          soft: 'rgb(var(--blue-soft) / <alpha-value>)',
          ink: 'rgb(var(--blue-ink) / <alpha-value>)',
        },
        orange: {
          DEFAULT: 'rgb(var(--orange) / <alpha-value>)',
          soft: 'rgb(var(--orange-soft) / <alpha-value>)',
        },
        ink: 'rgb(var(--ink) / <alpha-value>)',
        line: 'rgb(var(--line) / <alpha-value>)',
        danger: {
          DEFAULT: 'rgb(var(--danger) / <alpha-value>)',
          soft: 'rgb(var(--danger-soft) / <alpha-value>)',
        },
        success: {
          DEFAULT: 'rgb(var(--success) / <alpha-value>)',
          soft: 'rgb(var(--success-soft) / <alpha-value>)',
        },
      },
      borderRadius: {
        lg: 'var(--radius)',
        md: 'calc(var(--radius) - 2px)',
        sm: 'calc(var(--radius) - 4px)',
      },
      boxShadow: {
        card: '0 1px 2px rgb(16 36 58 / 0.04), 0 1px 3px rgb(16 36 58 / 0.05)',
        'card-hover': '0 2px 4px rgb(16 36 58 / 0.04), 0 10px 24px -6px rgb(16 36 58 / 0.12)',
        elevated: '0 12px 40px -8px rgb(1 30 57 / 0.25), 0 4px 12px -4px rgb(1 30 57 / 0.12)',
        brand: '0 1px 2px rgb(0 87 184 / 0.25), 0 4px 14px -4px rgb(0 87 184 / 0.45)',
      },
      keyframes: {
        'cc-in': {
          from: { opacity: '0', transform: 'translateY(6px)' },
          to: { opacity: '1', transform: 'translateY(0)' },
        },
        'cc-shimmer': {
          '100%': { transform: 'translateX(100%)' },
        },
      },
      animation: {
        'cc-in': 'cc-in 0.28s cubic-bezier(0.2, 0.8, 0.2, 1) both',
      },
    },
  },
  plugins: [],
} satisfies Config;
