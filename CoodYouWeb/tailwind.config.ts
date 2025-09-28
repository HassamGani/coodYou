import type { Config } from "tailwindcss";

const config: Config = {
  content: [
    "./app/**/*.{js,ts,jsx,tsx}",
    "./components/**/*.{js,ts,jsx,tsx}",
    "./lib/**/*.{js,ts,jsx,tsx}"
  ],
  theme: {
    extend: {
      colors: {
        brand: {
          DEFAULT: "#0B192C",
          accent: "#32D583",
          warning: "#FFB020",
          danger: "#F97066"
        }
      },
      boxShadow: {
        panel: "0 20px 45px rgba(15, 23, 42, 0.18)"
      }
    }
  },
  plugins: []
};

export default config;
