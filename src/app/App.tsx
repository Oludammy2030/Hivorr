import { useState, useRef, useEffect, useCallback } from "react";
import {
  Home, Search, Plus, MessageCircle, Wallet, User, Star, MapPin,
  Bell, Shield, TrendingUp, Briefcase, ArrowLeft, Send, Paperclip,
  Phone, Video, MoreVertical, CheckCheck, ArrowDownToLine, ArrowUpFromLine,
  Lock, Filter, X, Check, ChevronDown, Edit3, LogOut, Users, Settings,
  BarChart2, AlertCircle, Eye, Clock, Zap, Heart, Award, Globe, Cpu,
  Wrench, BookOpen, Menu, ChevronRight, Activity, FileText, CheckCircle,
  PauseCircle, DollarSign, Camera, Building, Target, Layers, ShoppingBag,
  Store, Truck, ShoppingCart, Package, SlidersHorizontal, Grid3X3, Boxes,
  ClipboardList, Navigation, Upload, Image, RotateCcw, Info,
} from "lucide-react";
import type { LucideIcon } from "lucide-react";

// ─── Hooks ───────────────────────────────────────────────────────────────────

function useBreakpoint() {
  const [w, setW] = useState(typeof window !== "undefined" ? window.innerWidth : 1280);
  useEffect(() => {
    const h = () => setW(window.innerWidth);
    window.addEventListener("resize", h);
    return () => window.removeEventListener("resize", h);
  }, []);
  return { isMobile: w < 768, isTablet: w >= 768 && w < 1024, isDesktop: w >= 1024, width: w };
}

// ─── Types ───────────────────────────────────────────────────────────────────

type Role = "employer" | "professional" | "admin";

type Screen =
  | "splash" | "onboarding" | "login" | "signup" | "otp" | "role-select"
  | "emp-home" | "emp-discover" | "emp-postjob" | "emp-jobs" | "emp-applications" | "emp-chat" | "emp-payments-overview" | "emp-wallet" | "emp-profile"
  | "pro-home" | "pro-discover" | "pro-jobs" | "pro-chat" | "pro-earnings-overview" | "pro-wallet" | "pro-profile"
  | "admin-overview" | "admin-users" | "admin-jobs" | "admin-payments" | "admin-marketplace" | "admin-categories" | "admin-workspace" | "admin-settings"
  | "admin-clients" | "admin-job-management" | "admin-hiring" | "admin-application-management" | "admin-verification" | "admin-payment-management" | "admin-request-management" | "admin-monitoring"
  | "admin-access" | "admin-notifications" | "admin-reports" | "admin-disputes"
  | "admin-support" | "admin-security-logs"
  | "activities" | "market-home" | "market-browse" | "market-saved" | "market-payments" | "market-profile" | "product-detail" | "cart" | "checkout" | "order-confirmation" | "orders" | "order-detail"
  | "errand-home" | "errand-request" | "errand-review" | "errand-tracking" | "errand-history" | "errand-payments" | "errand-profile"
  | "seller-home" | "seller-products" | "seller-listing" | "seller-orders" | "seller-invoices" | "seller-inventory" | "seller-analytics" | "seller-earnings" | "seller-profile"
  | "logistics-home" | "logistics-requests" | "logistics-active" | "logistics-history" | "logistics-earnings-overview" | "logistics-earnings" | "logistics-account-profile" | "logistics-profile"
  | "forgot-password" | "reset-sent";

type BP = ReturnType<typeof useBreakpoint>;
type SellerSubcategory = { id: string; name: string; description?: string; active: boolean; usage: number };
type SellerCategory = { id: string; name: string; description?: string; active: boolean; order: number; usage: number; subcategories: SellerSubcategory[] };

// ─── Design Tokens ───────────────────────────────────────────────────────────

const C = {
  primary: "#2D3FE7", primaryLight: "#EEF0FD",
  green: "#16A34A", greenLight: "#DCFCE7",
  orange: "#F97316", orangeLight: "#FFF7ED",
  red: "#EF4444", redLight: "#FEF2F2",
  purple: "#8B5CF6", purpleLight: "#F3F0FF",
  cyan: "#0891B2", cyanLight: "#E0F2FE",
  ink: "#0F1626", gray: "#6B7280", muted: "#9CA3AF",
  border: "rgba(15,22,38,0.07)", bg: "#F0F2F8", card: "#fff",
};

// ─── Data ────────────────────────────────────────────────────────────────────

const professionals = [
  { id: 1, name: "Amara Diallo", role: "Full-Stack Developer", rating: 4.9, reviews: 142, location: "Lagos, NG", rate: "$45/hr", avatar: "AD", color: C.primary, verified: true, skills: ["React", "Node.js", "PostgreSQL", "TypeScript"], jobs: 89, bio: "7 years building scalable fintech and e-commerce platforms across Africa.", available: true },
  { id: 2, name: "Kwame Asante", role: "UI/UX Designer", rating: 4.8, reviews: 98, location: "Accra, GH", rate: "$38/hr", avatar: "KA", color: C.green, verified: true, skills: ["Figma", "Prototyping", "Research", "Webflow"], jobs: 67, bio: "Product designer focused on human-centered design for African digital products.", available: true },
  { id: 3, name: "Fatima Hassan", role: "Electrician", rating: 4.7, reviews: 203, location: "Nairobi, KE", rate: "$25/hr", avatar: "FH", color: C.orange, verified: true, skills: ["Wiring", "Solar", "Maintenance", "HVAC"], jobs: 156, bio: "Certified electrician specialising in commercial and solar installations.", available: false },
  { id: 4, name: "Chidi Okonkwo", role: "Data Analyst", rating: 4.9, reviews: 77, location: "Abuja, NG", rate: "$42/hr", avatar: "CO", color: C.purple, verified: false, skills: ["Python", "Tableau", "SQL", "BigQuery"], jobs: 44, bio: "Data professional helping businesses make sense of their numbers.", available: true },
  { id: 5, name: "Nadia Mensah", role: "Plumber", rating: 4.6, reviews: 311, location: "Kumasi, GH", rate: "$20/hr", avatar: "NM", color: C.red, verified: true, skills: ["Pipes", "Drainage", "Fitting", "Gas"], jobs: 278, bio: "Expert plumber with 10+ years experience in residential and commercial.", available: true },
  { id: 6, name: "Seun Adeyemi", role: "Content Strategist", rating: 4.7, reviews: 55, location: "Ibadan, NG", rate: "$30/hr", avatar: "SA", color: C.cyan, verified: true, skills: ["SEO", "Copywriting", "Strategy", "Analytics"], jobs: 38, bio: "Helping African brands tell compelling stories that convert.", available: true },
];

const jobListings = [
  { id: 1, title: "Senior React Developer", company: "TechVentures Africa", budget: "$3,500", type: "Digital", location: "Remote", urgency: "urgent", posted: "2h ago", applicants: 12, category: "Development", status: "open", desc: "Build our next-gen fintech platform. 5+ years React/TypeScript required." },
  { id: 2, title: "Office Renovation & Electrical", company: "Lagos Properties Ltd", budget: "$1,200", type: "Physical", location: "Lagos, NG", urgency: "normal", posted: "5h ago", applicants: 7, category: "Construction", status: "in-progress", desc: "Full renovation of a 3-floor office building including electrical rewiring." },
  { id: 3, title: "Brand Identity Design Package", company: "StartupHub GH", budget: "$800", type: "Digital", location: "Remote", urgency: "normal", posted: "1d ago", applicants: 23, category: "Design", status: "open", desc: "Complete brand identity: logo, colors, typography, style guide." },
  { id: 4, title: "Home Plumbing Emergency Fix", company: "Private Client", budget: "$150", type: "Physical", location: "Nairobi, KE", urgency: "urgent", posted: "30m ago", applicants: 3, category: "Plumbing", status: "open", desc: "Burst pipe emergency — need an experienced plumber available today." },
  { id: 5, title: "Data Pipeline Architecture", company: "Fintech Solutions", budget: "$2,800", type: "Digital", location: "Remote", urgency: "normal", posted: "2d ago", applicants: 18, category: "Data", status: "completed", desc: "Design and implement a scalable data pipeline using Python, Airflow, BigQuery." },
  { id: 6, title: "Solar Panel Installation — 20 Units", company: "GreenEnergy NG", budget: "$4,200", type: "Physical", location: "Abuja, NG", urgency: "normal", posted: "3d ago", applicants: 9, category: "Energy", status: "open", desc: "Install 20 residential solar units across Abuja. Certified installers only." },
  { id: 7, title: "E-commerce UI/UX Redesign", company: "ShopAfrica Inc", budget: "$1,800", type: "Digital", location: "Remote", urgency: "normal", posted: "4d ago", applicants: 14, category: "Design", status: "in-progress", desc: "Redesign the checkout and product listing pages to improve conversion. Figma deliverable required." },
  { id: 8, title: "Mobile App — React Native", company: "PadelConnect", budget: "$5,200", type: "Digital", location: "Remote", urgency: "urgent", posted: "1d ago", applicants: 6, category: "Development", status: "in-progress", desc: "Build a cross-platform mobile app for sports booking. Authentication, payments, and real-time availability." },
  { id: 9, title: "Security Camera Installation", company: "Delta Logistics", budget: "$950", type: "Physical", location: "Accra, GH", urgency: "normal", posted: "2d ago", applicants: 5, category: "Electrical", status: "in-progress", desc: "Install and configure 12 IP security cameras across warehouse facility." },
  { id: 10, title: "Copywriting — SaaS Product Launch", company: "CloudOps Africa", budget: "$600", type: "Digital", location: "Remote", urgency: "normal", posted: "5d ago", applicants: 31, category: "Writing", status: "in-progress", desc: "Write landing page copy, email sequences, and onboarding tooltips for a new SaaS product launch." },
  { id: 11, title: "WordPress Site Migration", company: "MediaGroup West", budget: "$450", type: "Digital", location: "Remote", urgency: "normal", posted: "2w ago", applicants: 8, category: "Development", status: "completed", desc: "Migrate a 200-page WordPress site to a new host with zero downtime. Included SSL setup and performance tuning." },
  { id: 12, title: "Air Conditioning Units — Full Install", company: "Orbit Hotels", budget: "$2,100", type: "Physical", location: "Lagos, NG", urgency: "normal", posted: "3w ago", applicants: 11, category: "HVAC", status: "completed", desc: "Supply and install 8 split A/C units across 8 hotel rooms. Includes electrical work and commissioning." },
  { id: 13, title: "SEO Audit & Keyword Strategy", company: "RetailNG", budget: "$380", type: "Digital", location: "Remote", urgency: "normal", posted: "1mo ago", applicants: 19, category: "Marketing", status: "completed", desc: "Full technical SEO audit, competitor keyword gap analysis, and 3-month content strategy roadmap." },
  { id: 14, title: "Logo & Brand Guidelines", company: "Savannah Ventures", budget: "$720", type: "Digital", location: "Remote", urgency: "normal", posted: "1mo ago", applicants: 26, category: "Design", status: "completed", desc: "Design a modern logo and full brand guidelines document including colors, fonts, and usage rules." },
  { id: 15, title: "Generator Service & Repair", company: "Baobab Printing", budget: "$280", type: "Physical", location: "Abuja, NG", urgency: "urgent", posted: "5w ago", applicants: 4, category: "Electrical", status: "completed", desc: "Full service of 20KVA diesel generator including oil change, carburettor clean, and fault diagnostics." },
  { id: 16, title: "Python Scraper — Property Listings", company: "HomeFindr KE", budget: "$900", type: "Digital", location: "Remote", urgency: "normal", posted: "6w ago", applicants: 13, category: "Data", status: "completed", desc: "Build a Python web scraper to collect property listings from 5 Kenyan real-estate portals daily." },
];

const applications = [
  { id: 1, jobId: 1, pro: professionals[0], coverLetter: "I have 7 years of React experience and have built 3 fintech platforms. I can start immediately and deliver high-quality code.", proposedRate: "$45/hr", appliedDate: "Today, 08:30", status: "shortlisted" },
  { id: 2, jobId: 1, pro: professionals[3], coverLetter: "While my main focus is data, I have strong frontend skills and understand fintech deeply. My portfolio shows relevant work.", proposedRate: "$40/hr", appliedDate: "Today, 10:14", status: "pending" },
  { id: 3, jobId: 1, pro: professionals[1], coverLetter: "I'm a full-stack developer with React expertise. I've shipped 5 production apps in the fintech space across West Africa.", proposedRate: "$38/hr", appliedDate: "Yesterday", status: "pending" },
  { id: 4, jobId: 3, pro: professionals[1], coverLetter: "Brand identity is my speciality. I've worked with 12 startups across Africa creating cohesive visual systems from scratch.", proposedRate: "$38/hr", appliedDate: "Yesterday", status: "hired" },
  { id: 5, jobId: 3, pro: professionals[5], coverLetter: "I combine brand strategy with design execution. I'll deliver a complete brand system that speaks to your audience.", proposedRate: "$32/hr", appliedDate: "2d ago", status: "rejected" },
];

const empTransactions = [
  { id: 1, type: "debit", desc: "Payment to Amara Diallo", amount: "-$3,500", date: "Today, 09:14", status: "completed", job: "React Developer" },
  { id: 2, type: "escrow", desc: "Escrow: Office Renovation", amount: "$1,200", date: "Jun 28", status: "held", job: "Electrical Work" },
  { id: 3, type: "debit", desc: "Payment to Kwame Asante", amount: "-$800", date: "Jun 25", status: "completed", job: "Brand Design" },
  { id: 4, type: "debit", desc: "Payment to Nadia Mensah", amount: "-$150", date: "Jun 20", status: "completed", job: "Plumbing Fix" },
  { id: 5, type: "credit", desc: "Refund: Cancelled job", amount: "+$500", date: "Jun 18", status: "completed", job: "Refund" },
];

const proEarnings = [
  { id: 1, type: "credit", desc: "Payment: TechVentures Africa", amount: "+$3,500", date: "Today, 09:14", status: "completed", job: "React Developer" },
  { id: 2, type: "debit", desc: "Withdrawal to GTBank", amount: "-$2,000", date: "Yesterday", status: "completed", job: "" },
  { id: 3, type: "credit", desc: "Payment: StartupHub GH", amount: "+$800", date: "Jun 25", status: "completed", job: "Brand Design" },
  { id: 4, type: "escrow", desc: "Escrow pending: Fintech Solutions", amount: "$2,800", date: "Jun 22", status: "held", job: "Data Pipeline" },
  { id: 5, type: "debit", desc: "Platform fee (3%)", amount: "-$126", date: "Jun 20", status: "completed", job: "" },
];

const empChats = [
  { id: 1, name: "Amara Diallo", sub: "Full-Stack Developer", avatar: "AD", color: C.primary, time: "09:42", unread: 2, job: "Senior React Developer", msgs: [
    { from: "them", text: "I've pushed the first sprint to the repo. Please review!", time: "09:30" },
    { from: "me", text: "Great, I'll check it now.", time: "09:35" },
    { from: "them", text: "Let me know if you need any changes. I'm available today.", time: "09:42" },
  ]},
  { id: 2, name: "Kwame Asante", sub: "UI/UX Designer", avatar: "KA", color: C.green, time: "Yesterday", unread: 0, job: "Brand Identity Design", msgs: [
    { from: "me", text: "The logos look great! Can we try a darker shade on option B?", time: "Yesterday" },
    { from: "them", text: "Sure, I'll send revisions by 5pm.", time: "Yesterday" },
  ]},
  { id: 3, name: "Nadia Mensah", sub: "Plumber", avatar: "NM", color: C.red, time: "Jun 28", unread: 0, job: "Plumbing Emergency Fix", msgs: [
    { from: "them", text: "Job is done. All pipes are fixed and tested. ✓", time: "Jun 28" },
    { from: "me", text: "Thank you! Payment has been released.", time: "Jun 28" },
  ]},
];

const proChats = [
  { id: 1, name: "TechVentures Africa", sub: "Employer", avatar: "TV", color: C.primary, time: "09:50", unread: 3, job: "Senior React Developer", msgs: [
    { from: "them", text: "Can you add authentication to the user dashboard this sprint?", time: "09:40" },
    { from: "me", text: "Yes, I'll have it ready by Thursday.", time: "09:45" },
    { from: "them", text: "Perfect. Also update the API docs once done.", time: "09:50" },
  ]},
  { id: 2, name: "StartupHub GH", sub: "Employer", avatar: "SH", color: C.green, time: "Yesterday", unread: 0, job: "Brand Identity Design", msgs: [
    { from: "me", text: "Version 3 of the logo suite is ready for review.", time: "Yesterday" },
    { from: "them", text: "Love it! Let's proceed to the style guide.", time: "Yesterday" },
  ]},
];

const productImages = {
  fashion: "https://images.unsplash.com/photo-1768212566108-4ce4f329e4d2?crop=entropy&cs=tinysrgb&fit=crop&fm=jpg&q=80&w=900",
  bag: "https://images.unsplash.com/photo-1655682604476-96976c1917fb?crop=entropy&cs=tinysrgb&fit=crop&fm=jpg&q=80&w=900",
  groceries: "https://images.unsplash.com/photo-1690934164598-99267828e900?crop=entropy&cs=tinysrgb&fit=crop&fm=jpg&q=80&w=900",
  tech: "https://images.unsplash.com/photo-1786103749750-bd0aa9ba3259?crop=entropy&cs=tinysrgb&fit=crop&fm=jpg&q=80&w=900",
};

const products = [
  { id: 1, name: "Handwoven Market Tote", price: 18500, seller: "Zuri Craft House", location: "Lagos, NG", rating: 4.9, reviews: 86, category: "Fashion & Beauty", image: productImages.bag, badge: "Bestseller", stock: 12 },
  { id: 2, name: "Ankara Weekend Set", price: 32000, seller: "Ayo Studio", location: "Ibadan, NG", rating: 4.8, reviews: 41, category: "Fashion & Beauty", image: productImages.fashion, badge: "New", stock: 7 },
  { id: 3, name: "Farm Fresh Produce Box", price: 14500, seller: "Green Basket Co.", location: "Lagos, NG", rating: 4.7, reviews: 128, category: "Food & Groceries", image: productImages.groceries, badge: "Nearby", stock: 20 },
  { id: 4, name: "Smartwatch & Earbuds Set", price: 46500, seller: "Gadget Bay", location: "Abuja, NG", rating: 4.6, reviews: 64, category: "Electronics", image: productImages.tech, badge: "Trending", stock: 5 },
];

const marketCategories = [
  { label: "Food & Groceries", icon: ShoppingBag, color: C.green, bg: C.greenLight },
  { label: "Home & Living", icon: Home, color: C.orange, bg: C.orangeLight },
  { label: "Fashion & Beauty", icon: Star, color: C.purple, bg: C.purpleLight },
  { label: "Electronics", icon: Cpu, color: C.primary, bg: C.primaryLight },
  { label: "Health & Care", icon: Heart, color: C.red, bg: C.redLight },
  { label: "Sports & Outdoor", icon: Target, color: C.cyan, bg: C.cyanLight },
  { label: "Digital Products", icon: Globe, color: C.primary, bg: C.primaryLight },
  { label: "More", icon: Grid3X3, color: C.gray, bg: "#F4F6FB" },
];

const initialSellerCategories: SellerCategory[] = [
  { id: "fashion", name: "Fashion & Beauty", active: true, order: 1, usage: 2384, subcategories: [
    { id: "bags", name: "Bags & Accessories", active: true, usage: 684 },
    { id: "clothing", name: "Clothing", active: true, usage: 1052 },
    { id: "beauty", name: "Beauty & Personal Care", active: true, usage: 648 },
  ]},
  { id: "food", name: "Food & Groceries", active: true, order: 2, usage: 1946, subcategories: [
    { id: "fresh", name: "Fresh Produce", active: true, usage: 812 },
    { id: "pantry", name: "Pantry & Packaged Food", active: true, usage: 906 },
    { id: "beverages", name: "Beverages", active: false, usage: 228 },
  ]},
  { id: "electronics", name: "Electronics", active: true, order: 3, usage: 1488, subcategories: [
    { id: "phones", name: "Phones & Accessories", active: true, usage: 702 },
    { id: "computing", name: "Computing", active: true, usage: 514 },
    { id: "audio", name: "Audio", active: true, usage: 272 },
  ]},
  { id: "home", name: "Home & Living", active: true, order: 4, usage: 1312, subcategories: [
    { id: "decor", name: "Home Décor", active: true, usage: 504 },
    { id: "furniture", name: "Furniture", active: true, usage: 388 },
    { id: "kitchen", name: "Kitchen & Dining", active: true, usage: 420 },
  ]},
  { id: "digital", name: "Digital Products", active: true, order: 5, usage: 376, subcategories: [] },
  { id: "health", name: "Health & Care", active: false, order: 6, usage: 214, subcategories: [
    { id: "wellness", name: "Wellness", active: true, usage: 214 },
  ]},
];

// ─── Shared Components ───────────────────────────────────────────────────────

function Av({ initials, color, size = 40 }: { initials: string; color: string; size?: number }) {
  return (
    <div style={{ width: size, height: size, background: color + "20", border: `2px solid ${color}30`, borderRadius: "50%", flexShrink: 0, display: "flex", alignItems: "center", justifyContent: "center" }}>
      <span style={{ color, fontSize: size * 0.34, fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700 }}>{initials}</span>
    </div>
  );
}

function Pill({ label, color, bg }: { label: string; color: string; bg: string }) {
  return <span title={label} style={{ color, background: bg, fontSize: 11, fontWeight: 600, padding: "3px 9px", borderRadius: 20, whiteSpace: "nowrap", display: "inline-block", maxWidth: "100%", overflow: "hidden", textOverflow: "ellipsis", verticalAlign: "middle" }}>{label}</span>;
}

const activityHeroImages = {
  hiring: "https://images.unsplash.com/photo-1758876202980-0a28b744fb24?auto=format&fit=crop&w=1200&q=85",
  selling: "https://images.unsplash.com/photo-1783309239654-e9251288f75b?auto=format&fit=crop&w=1200&q=85",
  services: "https://images.unsplash.com/photo-1604933762021-54a5858c9832?auto=format&fit=crop&w=1200&q=85",
  logistics: "https://images.unsplash.com/photo-1638045420324-e431122074c2?auto=format&fit=crop&w=1200&q=85",
  errands: "https://images.unsplash.com/photo-1687422808384-c896d0efd4ab?auto=format&fit=crop&w=1200&q=85",
};

function getTimeGreeting(date = new Date()) {
  const hour = date.getHours();
  if (hour < 12) return "Good morning";
  if (hour < 18) return "Good afternoon";
  return "Good evening";
}

function safeGreetingName(preferred?: string, fallback = "there") {
  const value = preferred?.trim();
  return value && !/^(zero|null|undefined|n\/a)$/i.test(value) ? value : fallback;
}

function ActivityHero({
  bp,
  eyebrow,
  name,
  description,
  image,
  imageAlt,
  gradient,
  action,
  highlights,
  marginBottom = 0,
}: {
  bp: BP;
  eyebrow: string;
  name?: string;
  description: React.ReactNode;
  image: string;
  imageAlt: string;
  gradient: string;
  action?: React.ReactNode;
  highlights?: Array<{ value: string; label: string }>;
  marginBottom?: number;
}) {
  const displayName = safeGreetingName(name);
  return (
    <section style={{ background: gradient, borderRadius: 24, padding: bp.isMobile ? 18 : 28, color: "#fff", display: "grid", gridTemplateColumns: bp.isDesktop ? "minmax(0,1.3fr) minmax(260px,.7fr)" : "1fr", gap: bp.isMobile ? 18 : 24, alignItems: "center", overflow: "hidden", position: "relative", marginBottom }}>
      <div style={{ position: "relative", zIndex: 1, minWidth: 0 }}>
        <span style={{ display: "inline-block", maxWidth: "100%", padding: "5px 10px", borderRadius: 20, background: "rgba(255,255,255,.14)", border: "1px solid rgba(255,255,255,.2)", color: "rgba(255,255,255,.88)", fontSize: 10, fontWeight: 800, letterSpacing: .8 }}>{eyebrow}</span>
        <h1 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: bp.isMobile ? 25 : 31, lineHeight: 1.18, letterSpacing: -.5, marginTop: 11 }}>{getTimeGreeting()}, {displayName}.</h1>
        <p style={{ color: "rgba(255,255,255,.76)", fontSize: 13, lineHeight: 1.6, marginTop: 8, maxWidth: 620 }}>{description}</p>
        {action && <div style={{ marginTop: 16 }}>{action}</div>}
        {!bp.isMobile && highlights && (
          <div style={{ display: "flex", gap: 10, flexWrap: "wrap", marginTop: 20 }}>
            {highlights.map(item => (
              <div key={item.label} style={{ minWidth: 112, background: "rgba(255,255,255,.11)", borderRadius: 13, padding: "11px 14px", border: "1px solid rgba(255,255,255,.18)" }}>
                <p style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 18, color: "#fff" }}>{item.value}</p>
                <p style={{ fontSize: 10, color: "rgba(255,255,255,.66)", marginTop: 2 }}>{item.label}</p>
              </div>
            ))}
          </div>
        )}
      </div>
      <div style={{ height: bp.isDesktop ? 220 : bp.isMobile ? 150 : 190, minWidth: 0, position: "relative" }}>
        <div style={{ position: "absolute", inset: 8, borderRadius: 22, background: "rgba(255,255,255,.12)", transform: "rotate(3deg)" }} />
        <img src={image} alt={imageAlt} style={{ position: "relative", width: "100%", height: "100%", objectFit: "cover", objectPosition: "center", borderRadius: 20, border: "4px solid rgba(255,255,255,.18)", boxShadow: "0 16px 34px rgba(8,15,35,.2)" }} />
      </div>
    </section>
  );
}

function Stars({ rating, reviews }: { rating: number; reviews: number }) {
  return (
    <div style={{ display: "flex", alignItems: "center", gap: 4 }}>
      <Star size={12} fill="#F59E0B" color="#F59E0B" />
      <span style={{ fontSize: 12, fontWeight: 600, color: C.ink }}>{rating}</span>
      <span style={{ fontSize: 12, color: C.muted }}>({reviews})</span>
    </div>
  );
}

function StatCard({ label, value, sub, icon, color, bg, onClick }: { label: string; value: string; sub?: string; icon: React.ReactNode; color: string; bg: string; onClick?: () => void }) {
  return (
    <div onClick={onClick} style={{ background: C.card, borderRadius: 18, padding: "20px", border: `1px solid ${C.border}`, boxShadow: "0 2px 12px rgba(15,22,38,0.05)", cursor: onClick ? "pointer" : "default", transition: "all 0.2s", minWidth: 0 }}
      onMouseEnter={e => onClick && (e.currentTarget.style.boxShadow = "0 8px 24px rgba(45,63,231,0.1)")}
      onMouseLeave={e => onClick && (e.currentTarget.style.boxShadow = "0 2px 12px rgba(0,0,0,0.06)")}>
      <div style={{ display: "flex", alignItems: "center", gap: 12 }}>
        <div style={{ width: 46, height: 46, background: bg, borderRadius: 13, display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>{icon}</div>
        <div style={{ flex: 1, minWidth: 0 }}>
          <p style={{ fontSize: 12, color: C.muted, marginBottom: 2 }}>{label}</p>
          <p style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 22, color: C.ink, lineHeight: 1.1 }}>{value}</p>
          {sub && <p style={{ fontSize: 12, fontWeight: 600, color, marginTop: 2 }}>{sub}</p>}
        </div>
      </div>
    </div>
  );
}

function Section({ title, action, onAction, children, gap = 12 }: { title: string; action?: string; onAction?: () => void; children: React.ReactNode; gap?: number }) {
  return (
    <div>
      <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 14 }}>
        <h3 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 15, color: C.ink }}>{title}</h3>
        {action && <button onClick={onAction} style={{ color: C.primary, fontSize: 13, fontWeight: 600 }}>{action}</button>}
      </div>
      <div style={{ display: "flex", flexDirection: "column", gap }}>{children}</div>
    </div>
  );
}

function Btn({ children, onClick, variant = "primary", size = "md", icon, disabled = false }: { children: React.ReactNode; onClick?: () => void; variant?: "primary" | "secondary" | "ghost" | "danger"; size?: "sm" | "md" | "lg"; icon?: React.ReactNode; disabled?: boolean }) {
  const styles: Record<string, React.CSSProperties> = {
    primary: { background: C.primary, color: "#fff" },
    secondary: { background: C.primaryLight, color: C.primary },
    ghost: { background: "#F4F6FB", color: C.gray },
    danger: { background: C.redLight, color: C.red },
  };
  const pads: Record<string, string> = { sm: "7px 14px", md: "12px 20px", lg: "15px 24px" };
  const fz: Record<string, number> = { sm: 12, md: 14, lg: 16 };
  return (
    <button onClick={onClick} disabled={disabled} style={{ ...styles[variant], padding: pads[size], borderRadius: 12, fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: fz[size], display: "flex", alignItems: "center", justifyContent: "center", gap: 6, cursor: disabled ? "default" : "pointer", transition: "opacity 0.15s", whiteSpace: "nowrap", opacity: disabled ? .65 : 1 }}
      onMouseEnter={e => (e.currentTarget.style.opacity = "0.85")} onMouseLeave={e => (e.currentTarget.style.opacity = "1")}>
      {icon}{children}
    </button>
  );
}

function Input({ label, placeholder, type = "text", defaultValue, rows, value, min, onChange }: { label?: string; placeholder?: string; type?: string; defaultValue?: string; rows?: number; value?: string; min?: string; onChange?: React.ChangeEventHandler<HTMLInputElement> }) {
  const base: React.CSSProperties = { width: "100%", padding: "13px 14px", background: "#F4F6FB", borderRadius: 12, border: "1.5px solid transparent", fontSize: 14, outline: "none", boxSizing: "border-box", fontFamily: "'Inter',sans-serif", color: C.ink, transition: "border-color 0.2s" };
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 6 }}>
      {label && <label style={{ fontSize: 13, fontWeight: 600, color: "#374151" }}>{label}</label>}
      {rows
        ? <textarea rows={rows} placeholder={placeholder} style={{ ...base, resize: "none" }} onFocus={e => (e.target.style.borderColor = C.primary)} onBlur={e => (e.target.style.borderColor = "transparent")} />
        : <input type={type} placeholder={placeholder} defaultValue={defaultValue} value={value} min={min} onChange={onChange} style={base} onFocus={e => (e.target.style.borderColor = C.primary)} onBlur={e => (e.target.style.borderColor = "transparent")} />
      }
    </div>
  );
}

function SelectField({ label, value, onChange, options, disabled = false, emptyLabel = "Select an option" }: { label: string; value: string; onChange: (value: string) => void; options: { value: string; label: string }[]; disabled?: boolean; emptyLabel?: string }) {
  return <label style={{ display: "flex", flexDirection: "column", gap: 6 }}>
    <span style={{ fontSize: 13, fontWeight: 600, color: "#374151" }}>{label}</span>
    <div style={{ position: "relative" }}>
      <select value={value} onChange={event => onChange(event.target.value)} disabled={disabled} style={{ width: "100%", appearance: "none", padding: "13px 38px 13px 14px", background: disabled ? "#ECEFF5" : "#F4F6FB", borderRadius: 12, border: "1.5px solid transparent", fontSize: 14, outline: "none", color: disabled ? C.muted : C.ink, cursor: disabled ? "not-allowed" : "pointer" }}>
        {!value && <option value="">{emptyLabel}</option>}
        {options.map(option=><option key={option.value} value={option.value}>{option.label}</option>)}
      </select>
      <ChevronDown size={15} color={C.muted} style={{ position: "absolute", right: 13, top: "50%", transform: "translateY(-50%)", pointerEvents: "none" }}/>
    </div>
  </label>;
}

function ProductTaxonomyFields({ categories, categoryId, subcategoryId, onCategoryChange, onSubcategoryChange, isMobile }: { categories: SellerCategory[]; categoryId: string; subcategoryId: string; onCategoryChange: (id: string) => void; onSubcategoryChange: (id: string) => void; isMobile: boolean }) {
  const availableCategories=categories.filter(category=>category.active).sort((a,b)=>a.order-b.order);
  const selectedCategory=availableCategories.find(category=>category.id===categoryId);
  const availableSubcategories=(selectedCategory?.subcategories ?? []).filter(subcategory=>subcategory.active);
  return <div style={{ display:"grid",gridTemplateColumns:isMobile?"1fr":"1fr 1fr",gap:12 }}>
    <SelectField label="Category" value={selectedCategory?.id ?? ""} onChange={id=>{onCategoryChange(id);const first=categories.find(category=>category.id===id)?.subcategories.find(subcategory=>subcategory.active);onSubcategoryChange(first?.id ?? "");}} options={availableCategories.map(category=>({value:category.id,label:category.name}))} emptyLabel="No active categories available"/>
    <SelectField label="Subcategory" value={availableSubcategories.some(subcategory=>subcategory.id===subcategoryId)?subcategoryId:""} onChange={onSubcategoryChange} options={availableSubcategories.map(subcategory=>({value:subcategory.id,label:subcategory.name}))} disabled={!selectedCategory||availableSubcategories.length===0} emptyLabel={selectedCategory&&availableSubcategories.length===0?"No subcategories available":"Select a subcategory"}/>
  </div>;
}

function Card({ children, padding = 20, radius = 18, style }: { children: React.ReactNode; padding?: number; radius?: number; style?: React.CSSProperties }) {
  return <div style={{ background: C.card, borderRadius: radius, padding, border: `1px solid ${C.border}`, boxShadow: "0 2px 12px rgba(15,22,38,0.05)", minWidth: 0, ...style }}>{children}</div>;
}

function PrototypeDialog({ title, eyebrow, onClose, children, footer, maxWidth = 520 }: { title: string; eyebrow?: string; onClose: () => void; children: React.ReactNode; footer?: React.ReactNode; maxWidth?: number }) {
  const { isMobile } = useBreakpoint();
  return <div role="presentation" onClick={onClose} style={{ position: "fixed", inset: 0, zIndex: 80, background: "rgba(15,22,38,.46)", display: "flex", alignItems: isMobile ? "flex-end" : "center", justifyContent: "center", padding: isMobile ? 0 : 20 }}>
    <div role="dialog" aria-modal="true" aria-label={title} onClick={event => event.stopPropagation()} style={{ width: "100%", maxWidth: isMobile ? "none" : maxWidth, maxHeight: isMobile ? "88vh" : "min(760px,calc(100vh - 40px))", overflowY: "auto", background: C.card, borderRadius: isMobile ? "22px 22px 0 0" : 22, boxShadow: "0 28px 80px rgba(15,22,38,.28)", padding: isMobile ? "20px 18px calc(20px + env(safe-area-inset-bottom,0px))" : 24 }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", gap: 14 }}>
        <div>{eyebrow && <Pill label={eyebrow} color={C.primary} bg={C.primaryLight} />}<h2 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontSize: 19, fontWeight: 800, color: C.ink, marginTop: eyebrow ? 8 : 0 }}>{title}</h2></div>
        <button aria-label="Close dialog" onClick={onClose} style={{ width: 34, height: 34, borderRadius: 10, background: "#F4F6FB", display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}><X size={16} color={C.gray} /></button>
      </div>
      <div style={{ marginTop: 18 }}>{children}</div>
      {footer && <div style={{ display: "grid", gridTemplateColumns: "1fr 1.35fr", gap: 9, marginTop: 20, paddingTop: 16, borderTop: `1px solid ${C.border}` }}>{footer}</div>}
    </div>
  </div>;
}

function FinancialActionDialog({ mode, context, transactions, onClose }: { mode: "withdraw" | "statement"; context: string; transactions: Array<{ desc: string; amount: string; date: string }>; onClose: () => void }) {
  const [completed, setCompleted] = useState(false);
  if (mode === "withdraw") return <PrototypeDialog title="Withdraw funds" eyebrow={context.toUpperCase()} onClose={onClose} footer={<><Btn variant="ghost" onClick={onClose}>Cancel</Btn><Btn onClick={() => setCompleted(true)} icon={<ArrowUpFromLine size={14} />}>{completed ? "Request recorded" : "Review withdrawal"}</Btn></>}>
    {completed ? <div style={{ textAlign: "center", padding: 12 }}><CheckCircle size={34} color={C.green} /><h3 style={{ fontSize: 15, fontWeight: 800, color: C.ink, marginTop: 10 }}>Prototype withdrawal recorded</h3><p style={{ fontSize: 12, color: C.gray, lineHeight: 1.6, marginTop: 5 }}>No money was moved. A real withdrawal would require account verification and settlement processing.</p></div> : <div style={{ display: "flex", flexDirection: "column", gap: 14 }}><div style={{ background: C.greenLight, borderRadius: 14, padding: 14 }}><p style={{ fontSize: 10, color: C.gray }}>Withdrawable balance</p><p style={{ fontSize: 23, fontWeight: 800, color: C.green, marginTop: 3 }}>{SHARED_WALLET.withdrawable}</p></div><Input label="Amount" defaultValue="₦25,000" /><Input label="Payout account" defaultValue="GTBank · ending 4182" /><p style={{ fontSize: 10, color: C.muted, lineHeight: 1.5 }}>Prototype only. Submitting does not initiate a bank transfer or alter your wallet balance.</p></div>}
  </PrototypeDialog>;
  return <PrototypeDialog title="Financial statement" eyebrow={context.toUpperCase()} onClose={onClose} maxWidth={620} footer={<><Btn variant="ghost" onClick={onClose}>Close</Btn><Btn onClick={() => setCompleted(true)} icon={<ArrowDownToLine size={14} />}>{completed ? "Sample prepared" : "Prepare sample PDF"}</Btn></>}>
    <div style={{ display: "grid", gridTemplateColumns: "repeat(3,1fr)", gap: 8 }}>{[["Available",SHARED_WALLET.available],["Pending",SHARED_WALLET.pending],["Withdrawable",SHARED_WALLET.withdrawable]].map(([label,value])=><div key={label} style={{ padding: 10, borderRadius: 12, background: "#F8F9FC", minWidth: 0 }}><p style={{ fontSize: 9, color: C.muted }}>{label}</p><p style={{ fontSize: 12, fontWeight: 800, color: C.ink, marginTop: 3, overflow: "hidden", textOverflow: "ellipsis" }}>{value}</p></div>)}</div>
    <div style={{ marginTop: 16 }}>{transactions.map((transaction,index)=><div key={`${transaction.desc}-${index}`} style={{ display: "flex", alignItems: "center", gap: 10, padding: "11px 0", borderTop: index ? `1px solid ${C.border}` : "none" }}><div style={{ flex: 1, minWidth: 0 }}><p style={{ fontSize: 11, fontWeight: 700, color: C.ink, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{transaction.desc}</p><p style={{ fontSize: 9, color: C.muted, marginTop: 3 }}>{transaction.date}</p></div><strong style={{ fontSize: 11, color: transaction.amount.startsWith("+") ? C.green : C.ink }}>{transaction.amount}</strong></div>)}</div>
    <p style={{ fontSize: 10, color: completed ? C.green : C.muted, lineHeight: 1.5, marginTop: 12 }}>{completed ? "A sample statement has been prepared for this prototype." : "Statement data is illustrative and does not represent a bank-issued document."}</p>
  </PrototypeDialog>;
}

function JobRow({ job, extra, onAction }: { job: typeof jobListings[0]; extra?: React.ReactNode; onAction?: () => void }) {
  const statusColor = job.status === "open" ? C.green : job.status === "in-progress" ? C.orange : C.muted;
  const statusBg = job.status === "open" ? C.greenLight : job.status === "in-progress" ? C.orangeLight : "#F4F6FB";
  return (
    <div style={{ background: C.card, borderRadius: 16, padding: "16px 18px", boxShadow: "0 1px 6px rgba(0,0,0,0.05)", border: `1px solid ${C.border}` }}>
      <div style={{ display: "flex", gap: 10, alignItems: "flex-start", justifyContent: "space-between", marginBottom: 8 }}>
        <div style={{ flex: 1, minWidth: 0 }}>
          <div style={{ display: "flex", gap: 6, marginBottom: 6, flexWrap: "wrap" }}>
            <Pill label={job.category} color={C.primary} bg={C.primaryLight} />
            <Pill label={job.status.replace("-", " ")} color={statusColor} bg={statusBg} />
            {job.urgency === "urgent" && <Pill label="Urgent" color={C.red} bg={C.redLight} />}
          </div>
          <h4 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 15, color: C.ink, lineHeight: 1.3 }}>{job.title}</h4>
          <p style={{ fontSize: 13, color: C.gray, marginTop: 4 }}>{job.company} · {job.location}</p>
        </div>
        <div style={{ textAlign: "right", flexShrink: 0 }}>
          <p style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 16, color: C.green }}>{job.budget}</p>
          <p style={{ fontSize: 12, color: C.muted, marginTop: 2 }}>{job.applicants} applied</p>
        </div>
      </div>
      {extra || (onAction && <div style={{ display: "flex", gap: 8 }}><Btn size="sm" onClick={onAction}>View</Btn></div>)}
    </div>
  );
}

// ─── Chat Component (shared) ──────────────────────────────────────────────────

function ChatUI({ chats, bp, role }: { chats: typeof empChats; bp: BP; role: Role }) {
  const { isDesktop } = bp;
  const [active, setActive] = useState(0);
  const [input, setInput] = useState("");
  const [allChats, setAllChats] = useState(chats);
  const endRef = useRef<HTMLDivElement>(null);
  const cur = allChats[active];

  const send = () => {
    if (!input.trim()) return;
    setAllChats(prev => prev.map((c, i) => i === active
      ? { ...c, msgs: [...c.msgs, { from: "me" as const, text: input.trim(), time: new Date().toLocaleTimeString([], { hour: "2-digit", minute: "2-digit" }) }] }
      : c));
    setInput("");
  };
  useEffect(() => { endRef.current?.scrollIntoView({ behavior: "smooth" }); }, [allChats, active]);

  const listPane = (
    <div style={{ width: isDesktop ? 300 : "100%", flexShrink: 0, background: C.card, borderRight: isDesktop ? `1px solid ${C.border}` : "none", display: "flex", flexDirection: "column" }}>
      <div style={{ padding: "16px", borderBottom: `1px solid ${C.border}` }}>
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 12 }}>
          <h3 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 15, color: C.ink }}>Messages</h3>
          <button style={{ width: 30, height: 30, background: C.primaryLight, borderRadius: 9, display: "flex", alignItems: "center", justifyContent: "center" }}><Edit3 size={14} color={C.primary} /></button>
        </div>
        <div style={{ display: "flex", alignItems: "center", gap: 8, background: "#F4F6FB", borderRadius: 11, padding: "9px 12px" }}>
          <Search size={14} color={C.muted} />
          <input placeholder="Search..." style={{ flex: 1, background: "transparent", border: "none", outline: "none", fontSize: 13 }} />
        </div>
      </div>
      <div style={{ flex: 1, overflowY: "auto" }}>
        {allChats.map((c, i) => (
          <button key={c.id} onClick={() => setActive(i)} style={{ width: "100%", padding: "13px 16px", background: i === active ? C.primaryLight : C.card, textAlign: "left", borderBottom: `1px solid ${C.border}`, display: "flex", gap: 10, alignItems: "center" }}>
            <div style={{ position: "relative", flexShrink: 0 }}>
              <Av initials={c.avatar} color={c.color} size={44} />
              <div style={{ position: "absolute", bottom: 2, right: 2, width: 9, height: 9, background: C.green, borderRadius: "50%", border: "2px solid #fff" }} />
            </div>
            <div style={{ flex: 1, minWidth: 0 }}>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 1 }}>
                <span style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 13, color: C.ink }}>{c.name}</span>
                <span style={{ fontSize: 11, color: C.muted }}>{c.time}</span>
              </div>
              <p style={{ fontSize: 11, color: C.muted, marginBottom: 2 }}>re: {c.job}</p>
              <p style={{ fontSize: 12, color: c.unread > 0 ? C.ink : C.muted, fontWeight: c.unread > 0 ? 500 : 400, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{c.msgs[c.msgs.length - 1]?.text}</p>
            </div>
            {c.unread > 0 && <div style={{ width: 18, height: 18, background: C.primary, borderRadius: "50%", display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}><span style={{ fontSize: 10, fontWeight: 700, color: "#fff" }}>{c.unread}</span></div>}
          </button>
        ))}
      </div>
    </div>
  );

  const chatPane = (
    <div style={{ flex: 1, display: "flex", flexDirection: "column", minWidth: 0 }}>
      <div style={{ padding: "14px 18px", background: C.card, borderBottom: `1px solid ${C.border}`, display: "flex", alignItems: "center", gap: 12, flexShrink: 0 }}>
        <Av initials={cur.avatar} color={cur.color} size={38} />
        <div style={{ flex: 1 }}>
          <p style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 14, color: C.ink }}>{cur.name}</p>
          <p style={{ fontSize: 12, color: C.green, fontWeight: 500 }}>Online · {cur.sub}</p>
        </div>
        <div style={{ display: "flex", gap: 8 }}>
          {[Phone, Video, MoreVertical].map((Icon, i) => (
            <button key={i} style={{ width: 34, height: 34, background: "#F4F6FB", borderRadius: 10, display: "flex", alignItems: "center", justifyContent: "center" }}><Icon size={15} color={C.gray} /></button>
          ))}
        </div>
      </div>
      <div style={{ background: C.primaryLight, padding: "8px 14px", display: "flex", alignItems: "center", gap: 8, flexShrink: 0 }}>
        <Briefcase size={13} color={C.primary} />
        <span style={{ fontSize: 12, fontWeight: 600, color: C.primary, flex: 1 }}>{cur.job}</span>
        <ChevronRight size={13} color={C.primary} />
      </div>
      <div style={{ flex: 1, overflowY: "auto", padding: "16px 18px", display: "flex", flexDirection: "column", gap: 10, background: "#F8F9FC" }}>
        <div style={{ display: "flex", justifyContent: "center" }}>
          <span style={{ fontSize: 11, fontWeight: 600, color: C.muted, background: C.card, padding: "3px 12px", borderRadius: 20 }}>Today</span>
        </div>
        {cur.msgs.map((m, i) => (
          <div key={i} style={{ display: "flex", justifyContent: m.from === "me" ? "flex-end" : "flex-start" }}>
            <div style={{ maxWidth: "72%", background: m.from === "me" ? C.primary : C.card, borderRadius: m.from === "me" ? "18px 18px 4px 18px" : "18px 18px 18px 4px", padding: "11px 14px", boxShadow: "0 2px 8px rgba(0,0,0,0.07)" }}>
              <p style={{ fontSize: 14, color: m.from === "me" ? "#fff" : C.ink, lineHeight: 1.5 }}>{m.text}</p>
              <div style={{ display: "flex", alignItems: "center", gap: 4, justifyContent: "flex-end", marginTop: 4 }}>
                <span style={{ fontSize: 10, color: m.from === "me" ? "rgba(255,255,255,0.6)" : C.muted }}>{m.time}</span>
                {m.from === "me" && <CheckCheck size={12} color="rgba(255,255,255,0.6)" />}
              </div>
            </div>
          </div>
        ))}
        <div ref={endRef} />
      </div>
      <div style={{ padding: "12px 16px", background: C.card, borderTop: `1px solid ${C.border}`, display: "flex", gap: 10, alignItems: "center", flexShrink: 0 }}>
        <button style={{ width: 38, height: 38, background: "#F4F6FB", borderRadius: 11, display: "flex", alignItems: "center", justifyContent: "center" }}><Paperclip size={16} color={C.gray} /></button>
        <div style={{ flex: 1, display: "flex", alignItems: "center", background: "#F4F6FB", borderRadius: 13, padding: "10px 14px" }}>
          <input value={input} onChange={e => setInput(e.target.value)} onKeyDown={e => e.key === "Enter" && send()} placeholder="Type a message..." style={{ flex: 1, background: "transparent", border: "none", outline: "none", fontSize: 14, color: C.ink }} />
        </div>
        <button onClick={send} style={{ width: 42, height: 42, background: C.primary, borderRadius: 12, display: "flex", alignItems: "center", justifyContent: "center" }}><Send size={17} color="#fff" /></button>
      </div>
    </div>
  );

  return (
    <div style={{ flex: 1, display: "flex", overflow: "hidden" }}>
      {isDesktop ? <>{listPane}{chatPane}</> : listPane}
    </div>
  );
}

// ─── Auth Screens ─────────────────────────────────────────────────────────────

function SplashScreen({ onDone }: { onDone: () => void }) {
  useEffect(() => { const t = setTimeout(onDone, 1800); return () => clearTimeout(t); }, [onDone]);
  return (
    <div style={{ minHeight: "100vh", background: "linear-gradient(145deg,#1A2AD4 0%,#2D3FE7 50%,#4F5FEF 100%)", display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", gap: 24 }}>
      <div style={{ width: 96, height: 96, background: "rgba(255,255,255,0.15)", borderRadius: 28, border: "2px solid rgba(255,255,255,0.3)", display: "flex", alignItems: "center", justifyContent: "center" }}>
        <Zap size={48} color="#fff" fill="#fff" />
      </div>
      <div style={{ textAlign: "center" }}>
        <h1 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 48, color: "#fff", letterSpacing: -2 }}>Hivorr</h1>
        <p style={{ color: "rgba(255,255,255,0.7)", fontSize: 18, fontWeight: 500, marginTop: 8 }}>Africa's Workforce Marketplace</p>
      </div>
    </div>
  );
}

function OnboardingScreen({ onDone }: { onDone: () => void }) {
  const [slide, setSlide] = useState(0);
  const slides = [
    { icon: <Users size={56} color={C.primary} />, bg: C.primaryLight, accent: C.primary, title: "Hire Trusted Professionals", body: "Connect with verified experts for tech, trades, creative, and more — across Africa." },
    { icon: <Shield size={56} color={C.green} />, bg: C.greenLight, accent: C.green, title: "Secure Escrow Payments", body: "Funds held safely until work is done. Full protection for employers and professionals." },
    { icon: <TrendingUp size={56} color={C.orange} />, bg: C.orangeLight, accent: C.orange, title: "Grow Your Income", body: "Offer services, set rates, earn from clients across the continent — on your terms." },
  ];
  const s = slides[slide];
  return (
    <div style={{ minHeight: "100vh", background: "linear-gradient(135deg,#1A2AD4 0%,#2D3FE7 40%,#4F5FEF 100%)", display: "flex", alignItems: "center", justifyContent: "center", padding: 24 }}>
      <div style={{ width: "100%", maxWidth: 960, background: C.card, borderRadius: 28, boxShadow: "0 32px 80px rgba(0,0,0,0.2)", overflow: "hidden" }}>
        <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit,minmax(280px,1fr))", minHeight: 520 }}>
          <div style={{ background: s.bg, display: "flex", alignItems: "center", justifyContent: "center", padding: 48, transition: "background 0.4s" }}>
            <div style={{ textAlign: "center" }}>
              <div style={{ width: 130, height: 130, background: C.card, borderRadius: 36, boxShadow: "0 8px 32px rgba(0,0,0,0.08)", display: "flex", alignItems: "center", justifyContent: "center", margin: "0 auto 24px" }}>{s.icon}</div>
              <div style={{ display: "flex", gap: 8, justifyContent: "center" }}>
                {slides.map((_, i) => <div key={i} onClick={() => setSlide(i)} style={{ width: i === slide ? 28 : 8, height: 8, borderRadius: 4, background: i === slide ? s.accent : "#CBD5E1", cursor: "pointer", transition: "all 0.3s" }} />)}
              </div>
            </div>
          </div>
          <div style={{ padding: 48, display: "flex", flexDirection: "column", justifyContent: "center", gap: 20 }}>
            <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 8 }}>
              <div style={{ width: 36, height: 36, background: C.primary, borderRadius: 10, display: "flex", alignItems: "center", justifyContent: "center" }}><Zap size={20} color="#fff" fill="#fff" /></div>
              <span style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 18, color: C.ink }}>Hivorr</span>
            </div>
            <div>
              <p style={{ fontSize: 13, fontWeight: 600, color: s.accent, marginBottom: 8 }}>0{slide + 1} / 03</p>
              <h2 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 30, color: C.ink, lineHeight: 1.2, letterSpacing: -0.5 }}>{s.title}</h2>
              <p style={{ color: C.gray, fontSize: 16, lineHeight: 1.7, marginTop: 12 }}>{s.body}</p>
            </div>
            <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
              {slide < 2
                ? <Btn size="lg" onClick={() => setSlide(s => s + 1)} icon={<ChevronRight size={18} />}>Next</Btn>
                : <Btn size="lg" onClick={onDone}>Get Started →</Btn>}
              <button onClick={onDone} style={{ color: C.muted, fontWeight: 500, fontSize: 14, padding: "10px" }}>Skip intro</button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function LoginScreen({ goTo }: { goTo: (s: Screen) => void }) {
  return (
    <div style={{ minHeight: "100vh", background: "linear-gradient(135deg,#1A2AD4 0%,#2D3FE7 40%,#4F5FEF 100%)", display: "flex", alignItems: "center", justifyContent: "center", padding: 24 }}>
      <div style={{ width: "100%", maxWidth: 940, background: C.card, borderRadius: 28, boxShadow: "0 32px 80px rgba(0,0,0,0.2)", overflow: "hidden" }}>
        <div style={{ display: "grid", gridTemplateColumns: "repeat(auto-fit,minmax(280px,1fr))", minHeight: 500 }}>
          <div style={{ background: "linear-gradient(135deg,#1A2AD4,#2D3FE7)", padding: 48, display: "flex", flexDirection: "column", justifyContent: "space-between" }}>
            <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
              <div style={{ width: 36, height: 36, background: "rgba(255,255,255,0.2)", borderRadius: 10, display: "flex", alignItems: "center", justifyContent: "center" }}><Zap size={20} color="#fff" fill="#fff" /></div>
              <span style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 18, color: "#fff" }}>Hivorr</span>
            </div>
            <div>
              <h2 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 28, color: "#fff", lineHeight: 1.3, letterSpacing: -0.5 }}>Africa's #1 Workforce Marketplace</h2>
              <p style={{ color: "rgba(255,255,255,0.65)", fontSize: 15, marginTop: 12, lineHeight: 1.6 }}>Join 50,000+ professionals and employers building Africa's future together.</p>
            </div>
            <div style={{ display: "flex", gap: 24 }}>
              {[["52K+", "Professionals"], ["1.2K", "Companies"], ["$12M+", "Earned"]].map(([v, l]) => (
                <div key={l}><p style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 20, color: "#fff" }}>{v}</p><p style={{ fontSize: 12, color: "rgba(255,255,255,0.6)" }}>{l}</p></div>
              ))}
            </div>
          </div>
          <div style={{ padding: 48, display: "flex", flexDirection: "column", justifyContent: "center", gap: 20 }}>
            <div>
              <h1 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 26, color: C.ink, letterSpacing: -0.5 }}>Welcome back 👋</h1>
              <p style={{ color: C.gray, fontSize: 15, marginTop: 4 }}>Sign in to your account</p>
            </div>
            <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>
              <Input label="Email" placeholder="you@example.com" type="email" />
              <Input label="Password" placeholder="••••••••" type="password" />
              <div style={{ textAlign: "right" }}><span onClick={() => goTo("forgot-password")} style={{ color: C.primary, fontWeight: 600, fontSize: 13, cursor: "pointer" }}>Forgot password?</span></div>
              <Btn size="lg" onClick={() => goTo("role-select")}>Sign In</Btn>
            </div>
            <p style={{ textAlign: "center", fontSize: 14, color: C.gray }}>New to Hivorr? <span onClick={() => goTo("signup")} style={{ color: C.primary, fontWeight: 700, cursor: "pointer" }}>Create account</span></p>
          </div>
        </div>
      </div>
    </div>
  );
}

function SignupScreen({ goTo }: { goTo: (s: Screen) => void }) {
  return (
    <div style={{ minHeight: "100vh", background: "linear-gradient(135deg,#1A2AD4 0%,#2D3FE7 40%,#4F5FEF 100%)", display: "flex", alignItems: "center", justifyContent: "center", padding: 24 }}>
      <div style={{ width: "100%", maxWidth: 480, background: C.card, borderRadius: 28, padding: 40, boxShadow: "0 32px 80px rgba(0,0,0,0.2)" }}>
        <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 28 }}>
          <div style={{ width: 36, height: 36, background: C.primary, borderRadius: 10, display: "flex", alignItems: "center", justifyContent: "center" }}><Zap size={20} color="#fff" fill="#fff" /></div>
          <span style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 18, color: C.ink }}>Hivorr</span>
        </div>
        <h1 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 26, color: C.ink, letterSpacing: -0.5, marginBottom: 4 }}>Create account</h1>
        <p style={{ color: C.gray, fontSize: 15, marginBottom: 24 }}>Join Africa's workforce marketplace</p>
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }}>
          <Input label="Full name" placeholder="Amara Diallo" />
          <Input label="Email" placeholder="you@example.com" type="email" />
          <Input label="Phone" placeholder="+234 800 000 0000" type="tel" />
          <Input label="Country" placeholder="Nigeria" />
        </div>
        <div style={{ marginTop: 20 }}><Btn size="lg" onClick={() => goTo("otp")}>Send Verification Code</Btn></div>
        <p style={{ textAlign: "center", fontSize: 13, color: C.gray, marginTop: 16 }}>
          Already have an account? <span onClick={() => goTo("login")} style={{ color: C.primary, fontWeight: 700, cursor: "pointer" }}>Sign in</span>
        </p>
      </div>
    </div>
  );
}

function OTPScreen({ goTo }: { goTo: (s: Screen) => void }) {
  const [otp, setOtp] = useState(Array(6).fill(""));
  const refs = useRef<(HTMLInputElement | null)[]>([]);
  const handleInput = (i: number, v: string) => {
    if (!/^\d?$/.test(v)) return;
    const n = [...otp]; n[i] = v; setOtp(n);
    if (v && i < 5) refs.current[i + 1]?.focus();
  };
  return (
    <div style={{ minHeight: "100vh", background: "linear-gradient(135deg,#1A2AD4 0%,#2D3FE7 40%,#4F5FEF 100%)", display: "flex", alignItems: "center", justifyContent: "center", padding: 24 }}>
      <div style={{ width: "100%", maxWidth: 420, background: C.card, borderRadius: 28, padding: 48, textAlign: "center", boxShadow: "0 32px 80px rgba(0,0,0,0.2)" }}>
        <div style={{ width: 70, height: 70, background: C.primaryLight, borderRadius: 22, display: "flex", alignItems: "center", justifyContent: "center", margin: "0 auto 20px" }}><Shield size={34} color={C.primary} /></div>
        <h1 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 26, color: C.ink, letterSpacing: -0.5 }}>Verify your number</h1>
        <p style={{ color: C.gray, fontSize: 15, margin: "8px 0 28px", lineHeight: 1.6 }}>6-digit code sent to <strong style={{ color: C.ink }}>+234 800 000 0000</strong></p>
        <div style={{ display: "flex", gap: 10, justifyContent: "center", marginBottom: 24 }}>
          {otp.map((d, i) => (
            <input key={i} ref={el => { refs.current[i] = el; }} value={d} maxLength={1}
              onChange={e => handleInput(i, e.target.value)}
              onKeyDown={e => { if (e.key === "Backspace" && !d && i > 0) refs.current[i - 1]?.focus(); }}
              style={{ width: 50, height: 58, textAlign: "center", fontSize: 24, fontWeight: 700, color: C.ink, background: d ? C.primaryLight : "#F4F6FB", border: `2px solid ${d ? C.primary : "transparent"}`, borderRadius: 14, outline: "none" }} />
          ))}
        </div>
        <Btn size="lg" onClick={() => goTo("role-select")}>Verify & Continue</Btn>
        <p style={{ marginTop: 14, fontSize: 13, color: C.gray }}>Didn't receive it? <span style={{ color: C.primary, fontWeight: 700, cursor: "pointer" }}>Resend (0:42)</span></p>
      </div>
    </div>
  );
}

// ─── Forgot Password ──────────────────────────────────────────────────────────

function ForgotPasswordScreen({ goTo }: { goTo: (s: Screen) => void }) {
  const [email, setEmail] = useState("");
  const [touched, setTouched] = useState(false);
  const isValid = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);

  return (
    <div style={{ minHeight: "100vh", background: "linear-gradient(135deg,#1A2AD4 0%,#2D3FE7 40%,#4F5FEF 100%)", display: "flex", alignItems: "center", justifyContent: "center", padding: 24 }}>
      <div style={{ width: "100%", maxWidth: 440, background: C.card, borderRadius: 28, padding: 48, boxShadow: "0 32px 80px rgba(0,0,0,0.2)" }}>
        {/* Back */}
        <button onClick={() => goTo("login")} style={{ display: "flex", alignItems: "center", gap: 6, color: C.gray, fontWeight: 500, fontSize: 14, marginBottom: 32, cursor: "pointer" }}>
          <ArrowLeft size={18} /> Back to sign in
        </button>

        {/* Icon */}
        <div style={{ width: 68, height: 68, background: C.primaryLight, borderRadius: 22, display: "flex", alignItems: "center", justifyContent: "center", marginBottom: 24 }}>
          <Lock size={32} color={C.primary} />
        </div>

        <h1 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 26, color: C.ink, letterSpacing: -0.5, marginBottom: 6 }}>Forgot your password?</h1>
        <p style={{ color: C.gray, fontSize: 15, lineHeight: 1.6, marginBottom: 28 }}>No worries — enter your email address and we'll send you a reset link.</p>

        <div style={{ display: "flex", flexDirection: "column", gap: 6, marginBottom: 20 }}>
          <label style={{ fontSize: 13, fontWeight: 600, color: "#374151" }}>Email address</label>
          <input
            type="email"
            placeholder="you@example.com"
            value={email}
            onChange={e => { setEmail(e.target.value); setTouched(true); }}
            style={{ width: "100%", padding: "14px 16px", background: "#F4F6FB", borderRadius: 13, border: `1.5px solid ${touched && !isValid && email ? C.red : touched && isValid ? C.green : "transparent"}`, fontSize: 15, outline: "none", boxSizing: "border-box", color: C.ink, transition: "border-color 0.2s" }}
            onFocus={e => { if (!touched) e.target.style.borderColor = C.primary; }}
            onBlur={e => { e.target.style.borderColor = touched && !isValid && email ? C.red : touched && isValid ? C.green : "transparent"; }}
          />
          {touched && email && !isValid && (
            <p style={{ fontSize: 12, color: C.red, display: "flex", alignItems: "center", gap: 4 }}>
              <AlertCircle size={12} /> Please enter a valid email address
            </p>
          )}
        </div>

        <button
          onClick={() => { if (isValid) goTo("reset-sent"); else setTouched(true); }}
          style={{ width: "100%", background: isValid ? C.primary : "#E5E7EB", color: isValid ? "#fff" : C.muted, fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 16, padding: "15px", borderRadius: 13, cursor: isValid ? "pointer" : "not-allowed", transition: "all 0.2s", display: "flex", alignItems: "center", justifyContent: "center", gap: 8 }}>
          Send Reset Link
        </button>

        <p style={{ textAlign: "center", fontSize: 14, color: C.muted, marginTop: 20 }}>
          Remembered it? <span onClick={() => goTo("login")} style={{ color: C.primary, fontWeight: 700, cursor: "pointer" }}>Sign in</span>
        </p>
      </div>
    </div>
  );
}

function ResetSentScreen({ goTo }: { goTo: (s: Screen) => void }) {
  const [countdown, setCountdown] = useState(60);
  useEffect(() => {
    if (countdown <= 0) return;
    const t = setInterval(() => setCountdown(c => c - 1), 1000);
    return () => clearInterval(t);
  }, [countdown]);

  return (
    <div style={{ minHeight: "100vh", background: "linear-gradient(135deg,#1A2AD4 0%,#2D3FE7 40%,#4F5FEF 100%)", display: "flex", alignItems: "center", justifyContent: "center", padding: 24 }}>
      <div style={{ width: "100%", maxWidth: 440, background: C.card, borderRadius: 28, padding: 48, textAlign: "center", boxShadow: "0 32px 80px rgba(0,0,0,0.2)" }}>
        {/* Success icon */}
        <div style={{ width: 80, height: 80, background: C.greenLight, borderRadius: 26, display: "flex", alignItems: "center", justifyContent: "center", margin: "0 auto 24px" }}>
          <CheckCircle size={40} color={C.green} />
        </div>

        <h1 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 26, color: C.ink, letterSpacing: -0.5, marginBottom: 10 }}>Check your inbox</h1>
        <p style={{ color: C.gray, fontSize: 15, lineHeight: 1.7, marginBottom: 28 }}>
          We've sent a password reset link to <br />
          <strong style={{ color: C.ink }}>you@example.com</strong>.<br />
          The link expires in 15 minutes.
        </p>

        {/* Steps */}
        <div style={{ background: "#F8F9FC", borderRadius: 16, padding: "18px 20px", textAlign: "left", marginBottom: 28, display: "flex", flexDirection: "column", gap: 12 }}>
          {[["Open your email app", "Look in your primary or spam folder"], ["Click the reset link", "It will open a secure page"], ["Create a new password", "At least 8 characters recommended"]].map(([title, sub], i) => (
            <div key={i} style={{ display: "flex", gap: 12, alignItems: "flex-start" }}>
              <div style={{ width: 24, height: 24, background: C.primaryLight, borderRadius: "50%", display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0, marginTop: 1 }}>
                <span style={{ fontSize: 12, fontWeight: 800, color: C.primary }}>{i + 1}</span>
              </div>
              <div>
                <p style={{ fontSize: 13, fontWeight: 700, color: C.ink }}>{title}</p>
                <p style={{ fontSize: 12, color: C.muted, marginTop: 2 }}>{sub}</p>
              </div>
            </div>
          ))}
        </div>

        <button
          onClick={() => goTo("login")}
          style={{ width: "100%", background: C.primary, color: "#fff", fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 16, padding: "15px", borderRadius: 13, marginBottom: 14, cursor: "pointer" }}>
          Back to Sign In
        </button>

        <p style={{ fontSize: 14, color: C.muted }}>
          Didn't receive it?{" "}
          {countdown > 0
            ? <span style={{ color: C.muted }}>Resend in {countdown}s</span>
            : <span onClick={() => setCountdown(60)} style={{ color: C.primary, fontWeight: 700, cursor: "pointer" }}>Resend email</span>
          }
        </p>
      </div>
    </div>
  );
}

// ─── Role Selector ─────────────────────────────────────────────────────────────

function RoleSelectScreen({ onSelect }: { onSelect: (r: Role) => void }) {
  const [activeIdx, setActiveIdx] = useState(0);
  const scrollRef = useRef<HTMLDivElement>(null);
  const roles = [
    { role: "employer" as Role, icon: <Building size={40} color={C.primary} />, title: "I'm an Employer", sub: "Post jobs, hire professionals, manage projects & payments", color: C.primary, items: ["Post jobs & receive applications", "Hire verified professionals", "Escrow-protected payments", "Manage active projects"] },
    { role: "professional" as Role, icon: <Award size={40} color={C.green} />, title: "I'm a Professional", sub: "Find work, build your portfolio, and grow your income", color: C.green, items: ["Browse & apply for jobs", "Showcase your portfolio", "Track earnings & payments", "Chat with employers directly"] },
  ];

  const handleScroll = () => {
    if (!scrollRef.current) return;
    const { scrollLeft, offsetWidth } = scrollRef.current;
    const cardWidth = offsetWidth * 0.78 + 16;
    setActiveIdx(Math.round(scrollLeft / cardWidth));
  };

  return (
    <div style={{ minHeight: "100vh", background: "linear-gradient(145deg,#1A2AD4 0%,#2D3FE7 50%,#4F5FEF 100%)", display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", padding: "32px 0 40px" }}>
      {/* Header */}
      <div style={{ textAlign: "center", marginBottom: 36, padding: "0 24px" }}>
        <div style={{ display: "flex", alignItems: "center", justifyContent: "center", gap: 12, marginBottom: 16 }}>
          <div style={{ width: 44, height: 44, background: "rgba(255,255,255,0.2)", borderRadius: 13, display: "flex", alignItems: "center", justifyContent: "center" }}><Zap size={24} color="#fff" fill="#fff" /></div>
          <span style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 24, color: "#fff" }}>Hivorr</span>
        </div>
        <h1 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 30, color: "#fff", letterSpacing: -0.8, lineHeight: 1.25 }}>How will you use<br />Hivorr today?</h1>
        <p style={{ color: "rgba(255,255,255,0.65)", fontSize: 15, marginTop: 10 }}>Choose your experience — you can switch anytime</p>
      </div>

      {/* Carousel */}
      <div
        ref={scrollRef}
        onScroll={handleScroll}
        style={{ display: "flex", gap: 16, overflowX: "auto", scrollSnapType: "x mandatory", WebkitOverflowScrolling: "touch", width: "100%", paddingLeft: 24, paddingRight: 24, boxSizing: "border-box" }}
      >
        {roles.map((r, idx) => (
          <button
            key={r.role}
            onClick={() => onSelect(r.role)}
            style={{ flex: "0 0 78%", maxWidth: 340, scrollSnapAlign: "center", background: "#fff", borderRadius: 24, padding: 28, textAlign: "left", cursor: "pointer", border: `2px solid ${activeIdx === idx ? r.color : "transparent"}`, boxShadow: activeIdx === idx ? `0 20px 48px rgba(0,0,0,0.22)` : "0 6px 24px rgba(0,0,0,0.1)", transform: activeIdx === idx ? "scale(1.02)" : "scale(0.97)", transition: "all 0.25s" }}
          >
            <div style={{ width: 68, height: 68, background: r.color + "18", borderRadius: 20, display: "flex", alignItems: "center", justifyContent: "center", marginBottom: 18 }}>{r.icon}</div>
            <h3 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 20, color: C.ink, marginBottom: 6 }}>{r.title}</h3>
            <p style={{ fontSize: 14, color: C.gray, lineHeight: 1.55, marginBottom: 18 }}>{r.sub}</p>
            <div style={{ display: "flex", flexDirection: "column", gap: 9 }}>
              {r.items.map(item => (
                <div key={item} style={{ display: "flex", alignItems: "center", gap: 8 }}>
                  <div style={{ width: 18, height: 18, background: r.color + "18", borderRadius: "50%", display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}><Check size={10} color={r.color} strokeWidth={3} /></div>
                  <span style={{ fontSize: 13, color: "#374151" }}>{item}</span>
                </div>
              ))}
            </div>
            <div style={{ marginTop: 22, display: "flex", alignItems: "center", gap: 6, color: r.color, fontWeight: 700, fontSize: 14 }}>
              Enter as {r.title.split(" ").slice(1).join(" ")} <ChevronRight size={16} />
            </div>
          </button>
        ))}
      </div>

      {/* Dot indicators */}
      <div style={{ display: "flex", gap: 8, marginTop: 24, justifyContent: "center" }}>
        {roles.map((r, i) => (
          <div key={i} style={{ width: activeIdx === i ? 24 : 8, height: 8, borderRadius: 4, background: activeIdx === i ? "#fff" : "rgba(255,255,255,0.35)", transition: "all 0.3s" }} />
        ))}
      </div>

      <p style={{ color: "rgba(255,255,255,0.45)", fontSize: 12, marginTop: 16 }}>Swipe to explore all roles</p>
    </div>
  );
}

type ActivityId = "buy" | "hire" | "errand" | "sell" | "offer-services" | "logistics";
const ACTIVITY_DESTINATIONS: Record<ActivityId, Screen> = {
  buy: "market-home",
  hire: "emp-home",
  errand: "errand-home",
  sell: "seller-home",
  "offer-services": "pro-home",
  logistics: "logistics-home",
};

function ActivitySelectScreen({ onSelect, onAdmin }: { onSelect: (activity: ActivityId) => void; onAdmin: () => void }) {
  const bp = useBreakpoint();
  const sections = [
    {
      title: "Explore with Hivorr",
      body: "Shop, hire trusted professionals, or request help with a local errand.",
      items: [
        { id: "buy" as ActivityId, icon: ShoppingBag, title: "I Want to Buy", sub: "Discover products and shop for what you need.", action: "Start Shopping", color: C.primary, bg: C.primaryLight },
        { id: "hire" as ActivityId, icon: Users, title: "I Want to Hire", sub: "Find trusted professionals, post jobs, review applications, and manage your hires.", action: "Open Client Dashboard", color: C.purple, bg: C.purpleLight },
        { id: "errand" as ActivityId, icon: Navigation, title: "Send an Errand", sub: "Request an errand and connect with an eligible logistics provider.", action: "Create an Errand", color: C.orange, bg: C.orangeLight },
      ],
    },
    {
      title: "Earn with Hivorr",
      body: "Earn through product sales, professional services, or logistics fulfilment.",
      items: [
        { id: "sell" as ActivityId, icon: Store, title: "I Want to Sell", sub: "List your products, manage your shop, and grow your sales.", action: "Open Seller Dashboard", color: C.purple, bg: C.purpleLight },
        { id: "offer-services" as ActivityId, icon: Award, title: "I Want to Offer My Services", sub: "Showcase your expertise, find jobs, submit applications, and manage your professional work.", action: "Open Professional Dashboard", color: C.green, bg: C.greenLight },
        { id: "logistics" as ActivityId, icon: Truck, title: "I Want to Provide Logistics", sub: "Find available delivery and errand requests, fulfil assignments, and earn from completed deliveries.", action: "Open Logistics Dashboard", color: C.orange, bg: C.orangeLight },
      ],
    },
  ];

  return (
    <div style={{ minHeight: "100vh", background: C.bg, display: "flex", flexDirection: "column" }}>
      <div style={{ height: 72, background: C.card, borderBottom: `1px solid ${C.border}`, display: "flex", alignItems: "center", justifyContent: "space-between", padding: bp.isMobile ? "0 20px" : "0 48px", position: "sticky", top: 0, zIndex: 10 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
          <div style={{ width: 36, height: 36, background: C.primary, borderRadius: 10, display: "flex", alignItems: "center", justifyContent: "center" }}><Zap size={19} color="#fff" fill="#fff" /></div>
          <span style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 19, color: C.ink }}>Hivorr</span>
        </div>
        <Pill label="One account · Many activities" color={C.primary} bg={C.primaryLight} />
      </div>
      <main style={{ width: "100%", maxWidth: 1080, margin: "0 auto", padding: bp.isMobile ? "32px 18px 48px" : "48px 32px 64px" }}>
        <div style={{ maxWidth: 680, marginBottom: 34 }}>
          <p style={{ color: C.primary, fontSize: 12, fontWeight: 800, letterSpacing: 1.5, marginBottom: 8 }}>WELCOME TO YOUR HIVORR</p>
          <h1 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: bp.isMobile ? 30 : 40, color: C.ink, lineHeight: 1.15, letterSpacing: -1.2 }}>How do you want to use Hivorr today?</h1>
          <p style={{ fontSize: 15, lineHeight: 1.7, color: C.gray, marginTop: 12 }}>One account gives you access to multiple distinct Hivorr activities. Choose a workspace to continue.</p>
        </div>
        <div style={{ display: "flex", flexDirection: "column", gap: 26 }}>
          {sections.map(section => (
            <section key={section.title}>
              <h2 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontSize: 21, color: C.ink, fontWeight: 800 }}>{section.title}</h2>
              <p style={{ color: C.gray, fontSize: 13, lineHeight: 1.5, marginTop: 4, marginBottom: 14 }}>{section.body}</p>
              <div style={{ display: "grid", gridTemplateColumns: bp.isDesktop ? "repeat(3,1fr)" : "1fr", gap: 14 }}>
                {section.items.map(item => {
                  const Icon = item.icon;
                  return <button key={item.id} onClick={() => onSelect(item.id)} style={{ background: C.card, border: `1px solid ${C.border}`, borderRadius: 20, padding: bp.isMobile ? 18 : 22, textAlign: "left", boxShadow: "0 3px 14px rgba(15,22,38,0.06)", display: "flex", flexDirection: "column", alignItems: "flex-start", minHeight: 210 }}>
                    <div style={{ width: 52, height: 52, borderRadius: 16, background: item.bg, display: "flex", alignItems: "center", justifyContent: "center" }}><Icon size={24} color={item.color} /></div>
                    <h3 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontSize: 18, fontWeight: 800, color: C.ink, marginTop: 16 }}>{item.title}</h3>
                    <p style={{ fontSize: 13, lineHeight: 1.6, color: C.gray, marginTop: 7, flex: 1 }}>{item.sub}</p>
                    <span style={{ color: item.color, fontSize: 13, fontWeight: 800, display: "flex", alignItems: "center", gap: 5, marginTop: 16 }}>{item.action} <ChevronRight size={15} /></span>
                  </button>;
                })}
              </div>
            </section>
          ))}
        </div>
        <button onClick={onAdmin} style={{ display: "block", margin: "30px auto 0", color: C.muted, fontSize: 11 }}>Open admin prototype</button>
      </main>
    </div>
  );
}

// ─── App Shell ────────────────────────────────────────────────────────────────

type NavItem = { id: string; icon: LucideIcon; label: string; screen: Screen };

const empNav: NavItem[] = [
  { id: "dashboard", icon: Home, label: "Dashboard", screen: "emp-home" },
  { id: "services", icon: Search, label: "Find Services", screen: "emp-discover" },
  { id: "postjob", icon: Plus, label: "Post a Job", screen: "emp-postjob" },
  { id: "myjobs", icon: Briefcase, label: "My Jobs", screen: "emp-jobs" },
  { id: "applications", icon: Users, label: "Applications", screen: "emp-applications" },
  { id: "messages", icon: MessageCircle, label: "Messages", screen: "emp-chat" },
  { id: "payments", icon: Wallet, label: "Payments", screen: "emp-payments-overview" },
  { id: "profile", icon: User, label: "Profile", screen: "emp-profile" },
];

const proNav: NavItem[] = [
  { id: "dashboard", icon: Home, label: "Dashboard", screen: "pro-home" },
  { id: "findwork", icon: Search, label: "Find Work", screen: "pro-discover" },
  { id: "myjobs", icon: Briefcase, label: "My Jobs", screen: "pro-jobs" },
  { id: "messages", icon: MessageCircle, label: "Messages", screen: "pro-chat" },
  { id: "earnings", icon: Wallet, label: "Earnings", screen: "pro-earnings-overview" },
  { id: "analysis", icon: BarChart2, label: "Earnings Analysis", screen: "pro-wallet" },
  { id: "portfolio", icon: User, label: "Profile", screen: "pro-profile" },
];

const adminNav: NavItem[] = [];
const exploreAdminWorkspaces:{id:AdminWorkspaceId;label:string;icon:LucideIcon}[] = [
  { id:"buyer",label:"Manage Buyer Dashboard",icon:ShoppingBag },
  { id:"client",label:"Manage Client Dashboard",icon:Users },
  { id:"errand",label:"Manage Errand Requester Dashboard",icon:Navigation },
];
const earnAdminWorkspaces:{id:AdminWorkspaceId;label:string;icon:LucideIcon}[] = [
  { id:"seller",label:"Manage Seller Dashboard",icon:Store },
  { id:"professional",label:"Manage Professional Dashboard",icon:Award },
  { id:"logistics",label:"Manage Logistics Provider Dashboard",icon:Truck },
];
const platformAdminSubnav:NavItem[] = [
  { id:"support",icon:MessageCircle,label:"Support",screen:"admin-support" },
  { id:"security",icon:Shield,label:"Security Logs",screen:"admin-security-logs" },
];

function getNav(role: Role) {
  return role === "employer" ? empNav : role === "professional" ? proNav : adminNav;
}

function getRoleLabel(role: Role) {
  return role === "employer" ? "Client" : role === "professional" ? "Professional" : "Admin";
}

function getRoleColor(role: Role) {
  return role === "employer" ? C.primary : role === "professional" ? C.green : C.purple;
}

function getRoleInitials(role: Role) {
  return role === "employer" ? "EMP" : role === "professional" ? "PRO" : "ADM";
}

function Sidebar({ screen, role, goTo, collapsed, adminWorkspace, onAdminWorkspace }: { screen: Screen; role: Role; goTo: (s: Screen) => void; collapsed: boolean; adminWorkspace?:AdminWorkspaceId; onAdminWorkspace?:(workspace:AdminWorkspaceId)=>void }) {
  const nav = getNav(role);
  const [expandedAdmin,setExpandedAdmin]=useState<"explore"|"earn"|"platform"|null>("explore");
  const active = nav.find(n => n.screen === screen)?.id ?? nav[0]?.id;
  const roleColor = getRoleColor(role);
  useEffect(()=>{if(role==="admin"){if(screen==="admin-support"||screen==="admin-security-logs")setExpandedAdmin("platform");else if(screen==="admin-workspace"&&adminWorkspace&&["seller","professional","logistics"].includes(adminWorkspace))setExpandedAdmin("earn");else if(screen==="admin-workspace")setExpandedAdmin("explore");}},[screen,role,adminWorkspace]);

  return (
    <aside style={{ width: collapsed ? 66 : 224, flexShrink: 0, background: C.card, borderRight: `1px solid ${C.border}`, display: "flex", flexDirection: "column", height: "100vh", position: "sticky", top: 0, transition: "width 0.25s", overflow: "hidden" }}>
      <div style={{ padding: collapsed ? "20px 14px" : "20px 18px", borderBottom: `1px solid ${C.border}`, display: "flex", alignItems: "center", gap: 10 }}>
        <div style={{ width: 32, height: 32, background: C.primary, borderRadius: 9, flexShrink: 0, display: "flex", alignItems: "center", justifyContent: "center" }}>
          <Zap size={17} color="#fff" fill="#fff" />
        </div>
        {!collapsed && <span style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 17, color: C.ink, whiteSpace: "nowrap" }}>Hivorr</span>}
      </div>

      {!collapsed && (
        <div style={{ padding: "12px 14px", borderBottom: `1px solid ${C.border}`, background: roleColor + "0A" }}>
          <div style={{ display: "flex", alignItems: "center", gap: 8 }}>
            <div style={{ width: 8, height: 8, background: roleColor, borderRadius: "50%", flexShrink: 0 }} />
            <span style={{ fontSize: 12, fontWeight: 700, color: roleColor }}>{getRoleLabel(role)} Dashboard</span>
          </div>
        </div>
      )}

      <nav style={{ flex: 1, padding: collapsed ? "10px 9px" : "10px 10px", display: "flex", flexDirection: "column", gap: 2, overflowY: "auto" }}>
        {role === "admin" ? <>
          {!collapsed && <p style={{ fontSize: 9, fontWeight: 900, color: C.muted, letterSpacing: .8, padding: "7px 10px 5px" }}>DASHBOARD MANAGEMENT</p>}
          {([ ["explore","Explore with Hivorr",Search,exploreAdminWorkspaces], ["earn","Earn with Hivorr",TrendingUp,earnAdminWorkspaces] ] as const).map(([id,label,GroupIcon,items])=>{
            const expanded=expandedAdmin===id;
            const activeGroup=screen==="admin-workspace"&&items.some(item=>item.id===adminWorkspace);
            return <div key={id}>
              <button onClick={()=>collapsed?onAdminWorkspace?.(items[0].id):setExpandedAdmin(expanded?null:id)} style={{ display:"flex",alignItems:"center",gap:10,padding:collapsed?"10px 11px":"10px 12px",borderRadius:11,background:activeGroup?C.purpleLight:"transparent",color:activeGroup?C.purple:C.gray,fontWeight:800,fontSize:12,width:"100%",justifyContent:collapsed?"center":"flex-start",textAlign:"left" }}><GroupIcon size={17} color={activeGroup?C.purple:C.gray}/>{!collapsed&&<><span style={{ flex:1 }}>{label}</span><ChevronDown size={13} color={activeGroup?C.purple:C.muted} style={{ transform:expanded?"rotate(180deg)":"none" }}/></>}</button>
              {!collapsed&&expanded&&<div style={{ margin:"2px 0 7px 17px",paddingLeft:10,borderLeft:`1px solid ${C.border}`,display:"flex",flexDirection:"column",gap:1 }}>{items.map(item=><button key={item.id} onClick={()=>onAdminWorkspace?.(item.id)} style={{ padding:"8px 9px",borderRadius:8,textAlign:"left",fontSize:10,fontWeight:screen==="admin-workspace"&&adminWorkspace===item.id?800:600,color:screen==="admin-workspace"&&adminWorkspace===item.id?C.purple:C.gray,background:screen==="admin-workspace"&&adminWorkspace===item.id?C.purpleLight:"transparent",display:"flex",alignItems:"center",gap:7 }}><item.icon size={12} color={screen==="admin-workspace"&&adminWorkspace===item.id?C.purple:C.muted}/>{item.label}</button>)}</div>}
            </div>;
          })}
          {!collapsed&&<p style={{ fontSize: 9, fontWeight: 900, color: C.muted, letterSpacing: .8, padding: "12px 10px 5px", borderTop:`1px solid ${C.border}`, marginTop:5 }}>PLATFORM ADMIN</p>}
          <div><button onClick={()=>collapsed?goTo("admin-support"):setExpandedAdmin(expandedAdmin==="platform"?null:"platform")} style={{ display:"flex",alignItems:"center",gap:10,padding:collapsed?"10px 11px":"10px 12px",borderRadius:11,background:["admin-support","admin-security-logs"].includes(screen)?C.purpleLight:"transparent",color:["admin-support","admin-security-logs"].includes(screen)?C.purple:C.gray,fontWeight:800,fontSize:12,width:"100%",justifyContent:collapsed?"center":"flex-start",textAlign:"left" }}><Shield size={17} color={["admin-support","admin-security-logs"].includes(screen)?C.purple:C.gray}/>{!collapsed&&<><span style={{ flex:1 }}>Platform Admin</span><ChevronDown size={13} color={C.muted} style={{ transform:expandedAdmin==="platform"?"rotate(180deg)":"none" }}/></>}</button>{!collapsed&&expandedAdmin==="platform"&&<div style={{ margin:"2px 0 7px 17px",paddingLeft:10,borderLeft:`1px solid ${C.border}`,display:"flex",flexDirection:"column",gap:1 }}>{platformAdminSubnav.map(item=><button key={item.id} onClick={()=>goTo(item.screen)} style={{ padding:"8px 9px",borderRadius:8,textAlign:"left",fontSize:10,fontWeight:screen===item.screen?800:600,color:screen===item.screen?C.purple:C.gray,background:screen===item.screen?C.purpleLight:"transparent",display:"flex",alignItems:"center",gap:7 }}><item.icon size={12} color={screen===item.screen?C.purple:C.muted}/>{item.label}</button>)}</div>}</div>
        </> : nav.map(item => {
          const isActive = active === item.id;
          const isPost = item.id === "postjob";
          return <button key={item.id} onClick={() => goTo(item.screen)} style={{ display: "flex", alignItems: "center", gap: 10, padding: collapsed ? "10px 11px" : "10px 12px", borderRadius: 11, background: isPost ? C.primary : isActive ? roleColor + "18" : "transparent", color: isPost ? "#fff" : isActive ? roleColor : C.gray, fontWeight: 600, fontSize: 13, transition: "all 0.15s", width: "100%", justifyContent: collapsed ? "center" : "flex-start", whiteSpace: "nowrap", cursor: "pointer" }}><item.icon size={17} color={isPost ? "#fff" : isActive ? roleColor : C.gray} />{!collapsed && item.label}</button>;
        })}
      </nav>

      <div style={{ padding: collapsed ? "12px 9px" : "12px 12px", borderTop: `1px solid ${C.border}` }}>
        <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
          <Av initials={role === "employer" ? "TV" : role === "professional" ? "AD" : "SA"} color={roleColor} size={32} />
          {!collapsed && (
            <div style={{ flex: 1, minWidth: 0 }}>
              <p style={{ fontSize: 13, fontWeight: 700, color: C.ink, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{role === "employer" ? "TechVentures Africa" : role === "professional" ? "Amara Diallo" : "Super Admin"}</p>
              <p style={{ fontSize: 11, color: C.muted }}>{getRoleLabel(role)}</p>
            </div>
          )}
          {!collapsed && <LogOut size={15} color={C.muted} style={{ cursor: "pointer", flexShrink: 0 }} />}
        </div>
      </div>
    </aside>
  );
}

function TopBar({ title, screen, role, goTo, onMenu, showBack, backScreen }: { title: string; screen: Screen; role: Role; goTo: (s: Screen) => void; onMenu: () => void; showBack?: boolean; backScreen?: Screen }) {
  const roleColor = getRoleColor(role);
  const { isMobile } = useBreakpoint();
  return (
    <div style={{ height: 62, background: C.card, borderBottom: `1px solid ${C.border}`, display: "flex", alignItems: "center", justifyContent: "space-between", padding: isMobile ? "0 12px" : "0 20px", flexShrink: 0, position: "sticky", top: 0, zIndex: 30, gap: 10 }}>
      <div style={{ display: "flex", alignItems: "center", gap: 10, minWidth: 0 }}>
        <button onClick={showBack ? () => goTo(backScreen!) : onMenu} style={{ width: 36, height: 36, background: "#F4F6FB", borderRadius: 10, display: "flex", alignItems: "center", justifyContent: "center" }}>
          {showBack ? <ArrowLeft size={17} color={C.gray} /> : <Menu size={17} color={C.gray} />}
        </button>
        <span style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: isMobile ? 14 : 16, color: C.ink, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{title}</span>
      </div>
      <div style={{ display: "flex", alignItems: "center", gap: isMobile ? 6 : 10, flexShrink: 0 }}>
        {role !== "admin" && (
          <button aria-label="Switch activities" onClick={() => goTo("role-select")} style={{ width: isMobile ? 36 : "auto", height: 36, padding: isMobile ? 0 : "0 11px", background: C.primaryLight, borderRadius: 10, display: "flex", alignItems: "center", justifyContent: "center", gap: 6, color: C.primary, fontSize: 12, fontWeight: 700 }}>
            <RotateCcw size={15} color={C.primary} />{!isMobile && "Activities"}
          </button>
        )}
        <div style={{ position: "relative" }}>
          <button style={{ width: 36, height: 36, background: "#F4F6FB", borderRadius: 10, display: "flex", alignItems: "center", justifyContent: "center" }}><Bell size={17} color={C.gray} /></button>
          <div style={{ position: "absolute", top: 7, right: 7, width: 7, height: 7, background: C.red, borderRadius: "50%", border: "1.5px solid #fff" }} />
        </div>
        {!isMobile && <div style={{ display: "flex", alignItems: "center", gap: 8, padding: "6px 10px", background: roleColor + "12", borderRadius: 20 }}>
          <div style={{ width: 8, height: 8, background: roleColor, borderRadius: "50%" }} />
          <span style={{ fontSize: 12, fontWeight: 700, color: roleColor }}>{getRoleLabel(role)}</span>
        </div>}
        <Av initials={role === "employer" ? "TV" : "AD"} color={roleColor} size={34} />
      </div>
    </div>
  );
}

type MobileNavEntry = {
  key: string;
  icon: LucideIcon;
  label: string;
  screen: Screen;
  isPrimary?: boolean;
};

function MobileNavBar({ items, activeKey, color, goTo }: { items: MobileNavEntry[]; activeKey?: string; color: string; goTo: (s: Screen) => void }) {
  return (
    <div style={{ position: "fixed", bottom: 0, left: 0, right: 0, background: C.card, borderTop: `1px solid ${C.border}`, boxShadow: "0 -8px 24px rgba(15,22,38,.06)", display: "flex", zIndex: 40, paddingBottom: "env(safe-area-inset-bottom,4px)" }}>
      {items.map(item => {
        const isActive = activeKey === item.key;
        return (
          <button key={item.key} aria-label={item.label} title={item.label} onClick={() => goTo(item.screen)} style={{ flex: 1, minWidth: 0, display: "flex", flexDirection: "column", alignItems: "center", justifyContent: "center", paddingTop: 10, paddingBottom: 8, gap: 3, position: "relative" }}>
            {item.isPrimary
              ? <div style={{ width: 40, height: 40, background: color, borderRadius: 13, display: "flex", alignItems: "center", justifyContent: "center", marginTop: -8, boxShadow: `0 4px 12px ${color}55` }}><item.icon size={19} color="#fff" /></div>
              : <>
                {isActive && <div style={{ position: "absolute", top: 0, left: "50%", transform: "translateX(-50%)", width: 16, height: 3, background: color, borderRadius: "0 0 3px 3px" }} />}
                <item.icon size={19} color={isActive ? color : C.muted} />
                <span style={{ maxWidth: "100%", padding: "0 2px", overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap", fontSize: 9, fontWeight: isActive ? 700 : 500, color: isActive ? color : C.muted }}>{item.label}</span>
              </>}
          </button>
        );
      })}
    </div>
  );
}

function MobileBottomNav({ screen, role, goTo }: { screen: Screen; role: Role; goTo: (s: Screen) => void }) {
  const nav = getNav(role);
  const mobileIds = role === "employer"
    ? ["dashboard", "services", "postjob", "payments", "profile"]
    : role === "professional"
      ? ["dashboard", "findwork", "myjobs", "earnings", "portfolio"]
      : ["overview", "users", "jobs", "payments", "settings"];
  const items: MobileNavEntry[] = nav
    .filter(item => mobileIds.includes(item.id))
    .map(item => ({ key: item.id, icon: item.icon, label: item.label, screen: item.screen, isPrimary: item.id === "postjob" }));
  const activeKey = nav.find(item => item.screen === screen)?.id ?? nav[0].id;
  return <MobileNavBar items={items} activeKey={activeKey} color={getRoleColor(role)} goTo={goTo} />;
}

// ─── Employer Screens ─────────────────────────────────────────────────────────

function EmpHome({ goTo, bp }: { goTo: (s: Screen) => void; bp: BP }) {
  const { isDesktop, isTablet, isMobile } = bp;
  const p = isMobile ? "16px 16px 80px" : "28px";
  const recentApps = applications.slice(0, 3);
  return (
    <div style={{ flex: 1, overflowY: "auto", padding: p }}>
      <ActivityHero
        bp={bp}
        eyebrow="I WANT TO HIRE"
        name="TechVentures Africa"
        description={<>You have <strong style={{ color: "#fff" }}>34 new applications</strong> across your active jobs. Find trusted professionals and keep every hire moving.</>}
        image={activityHeroImages.hiring}
        imageAlt="Colleagues reviewing professional work together"
        gradient="linear-gradient(125deg,#1727BE 0%,#2D3FE7 58%,#5263F4 100%)"
        highlights={[{ value: "8", label: "Jobs Posted" }, { value: "3", label: "Active Hires" }, { value: "$12,400", label: "Total Spent" }, { value: "34", label: "Applications" }]}
        marginBottom={24}
      />

      <div style={{ display: "grid", gridTemplateColumns: isDesktop ? "1fr 320px" : "1fr", gap: 24 }}>
        <div style={{ display: "flex", flexDirection: "column", gap: 24 }}>
          {/* Stats (mobile only) — original 2×2 grid */}
          {isMobile && (
            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }}>
              {[
                { label: "Jobs Posted", value: "8", sub: "+2 this week", icon: <Briefcase size={20} color={C.primary} />, color: C.primary, bg: C.primaryLight },
                { label: "Active Hires", value: "3", sub: "in progress", icon: <Users size={20} color={C.green} />, color: C.green, bg: C.greenLight },
                { label: "Total Spent", value: "$12.4K", sub: "this month", icon: <DollarSign size={20} color={C.orange} />, color: C.orange, bg: C.orangeLight },
                { label: "Applications", value: "34", sub: "awaiting review", icon: <FileText size={20} color={C.purple} />, color: C.purple, bg: C.purpleLight },
              ].map(s => <StatCard key={s.label} {...s} />)}
            </div>
          )}

          {/* Quick Actions — horizontal scroll carousel on mobile & tablet, 3-col grid on desktop */}
          <div>
            <Section title="Quick Actions">
              {isDesktop ? (
                <div style={{ display: "grid", gridTemplateColumns: "repeat(3,1fr)", gap: 10 }}>
                  {[
                    { icon: <Plus size={20} color={C.primary} />, label: "Post a Job", bg: C.primaryLight, onClick: () => goTo("emp-postjob") },
                    { icon: <Users size={20} color={C.green} />, label: "View Applications", bg: C.greenLight, onClick: () => goTo("emp-applications") },
                    { icon: <MessageCircle size={20} color={C.orange} />, label: "Message Hires", bg: C.orangeLight, onClick: () => goTo("emp-chat") },
                  ].map(a => (
                    <button key={a.label} onClick={a.onClick} style={{ background: C.card, borderRadius: 14, padding: "16px 12px", display: "flex", flexDirection: "column", alignItems: "center", gap: 9, boxShadow: "0 2px 10px rgba(0,0,0,0.05)", border: `1px solid ${C.border}`, cursor: "pointer", transition: "all 0.2s" }}
                      onMouseEnter={e => { e.currentTarget.style.transform = "translateY(-2px)"; }}
                      onMouseLeave={e => { e.currentTarget.style.transform = "none"; }}>
                      <div style={{ width: 44, height: 44, background: a.bg, borderRadius: 13, display: "flex", alignItems: "center", justifyContent: "center" }}>{a.icon}</div>
                      <span style={{ fontSize: 12, fontWeight: 600, color: "#374151", textAlign: "center" }}>{a.label}</span>
                    </button>
                  ))}
                </div>
              ) : (
                <div style={{ position: "relative" }}>
                  <div
                    className="hide-scrollbar"
                    style={{ display: "flex", gap: 12, overflowX: "auto", scrollSnapType: "x mandatory", WebkitOverflowScrolling: "touch", paddingBottom: 6, msOverflowStyle: "none" }}
                  >
                    {[
                      { icon: <Plus size={22} color={C.primary} />, label: "Post a Job", bg: C.primaryLight, onClick: () => goTo("emp-postjob") },
                      { icon: <Users size={22} color={C.green} />, label: "View Applications", bg: C.greenLight, onClick: () => goTo("emp-applications") },
                      { icon: <MessageCircle size={22} color={C.orange} />, label: "Message Hires", bg: C.orangeLight, onClick: () => goTo("emp-chat") },
                    ].map(a => (
                      <button
                        key={a.label}
                        onClick={a.onClick}
                        className="hide-scrollbar"
                        style={{
                          flex: "0 0 calc((100% - 24px) / 2.5)",
                          scrollSnapAlign: "start",
                          background: C.card,
                          borderRadius: 14,
                          padding: "18px 12px",
                          display: "flex",
                          flexDirection: "column",
                          alignItems: "center",
                          gap: 10,
                          boxShadow: "0 2px 10px rgba(0,0,0,0.05)",
                          border: `1px solid ${C.border}`,
                          cursor: "pointer",
                        }}
                      >
                        <div style={{ width: 48, height: 48, background: a.bg, borderRadius: 14, display: "flex", alignItems: "center", justifyContent: "center" }}>{a.icon}</div>
                        <span style={{ fontSize: 12, fontWeight: 600, color: "#374151", textAlign: "center", lineHeight: 1.3 }}>{a.label}</span>
                      </button>
                    ))}
                  </div>
                </div>
              )}
            </Section>
          </div>

          {/* Active Jobs */}
          <Section title="Active Jobs" action="Manage all" onAction={() => goTo("emp-jobs")}>
            {jobListings.filter(j => j.status !== "completed").slice(0, 3).map(j => (
              <JobRow key={j.id} job={j} onAction={() => goTo("emp-applications")} extra={
                <div style={{ display: "flex", gap: 8, marginTop: 8 }}>
                  <Btn size="sm" onClick={() => goTo("emp-applications")} icon={<Users size={13} />}>{j.applicants} Applicants</Btn>
                  <Btn size="sm" variant="ghost" onClick={() => goTo("emp-chat")} icon={<MessageCircle size={13} />}>Message</Btn>
                </div>
              } />
            ))}
          </Section>

          {/* Recent Applications */}
          <Section title="Recent Applications" action="View all" onAction={() => goTo("emp-applications")}>
            {recentApps.map(app => (
              <div key={app.id} style={{ background: C.card, borderRadius: 16, padding: "14px 16px", border: `1px solid ${C.border}`, display: "flex", gap: 12, alignItems: "center" }}>
                <Av initials={app.pro.avatar} color={app.pro.color} size={44} />
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ display: "flex", alignItems: "center", gap: 6, marginBottom: 2 }}>
                    <p style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 14, color: C.ink }}>{app.pro.name}</p>
                    {app.pro.verified && <Shield size={12} color={C.green} fill={C.green} />}
                  </div>
                  <p style={{ fontSize: 12, color: C.gray }}>{app.pro.role} · {app.proposedRate}</p>
                  <Stars rating={app.pro.rating} reviews={app.pro.reviews} />
                </div>
                <div style={{ display: "flex", flexDirection: "column", gap: 6, alignItems: "flex-end" }}>
                  <Pill label={app.status} color={app.status === "shortlisted" ? C.primary : app.status === "hired" ? C.green : app.status === "rejected" ? C.red : C.orange} bg={app.status === "shortlisted" ? C.primaryLight : app.status === "hired" ? C.greenLight : app.status === "rejected" ? C.redLight : C.orangeLight} />
                  <span style={{ fontSize: 11, color: C.muted }}>{app.appliedDate}</span>
                </div>
              </div>
            ))}
          </Section>
        </div>

        {/* Right sidebar */}
        {isDesktop && (
          <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
              {[
                { label: "Jobs Posted", value: "8", sub: "+2 this week", icon: <Briefcase size={18} color={C.primary} />, color: C.primary, bg: C.primaryLight },
                { label: "Active Hires", value: "3", sub: "in progress", icon: <Users size={18} color={C.green} />, color: C.green, bg: C.greenLight },
                { label: "Total Spent", value: "$12.4K", sub: "this month", icon: <DollarSign size={18} color={C.orange} />, color: C.orange, bg: C.orangeLight },
                { label: "Open Apps", value: "34", sub: "to review", icon: <FileText size={18} color={C.purple} />, color: C.purple, bg: C.purpleLight },
              ].map(s => <StatCard key={s.label} {...s} />)}
            </div>

            {/* Spending */}
            <Card>
              <p style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 14, color: C.ink, marginBottom: 16 }}>Spending Overview</p>
              <div style={{ marginBottom: 12 }}>
                <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 6 }}>
                  <span style={{ fontSize: 13, color: C.gray }}>Monthly budget used</span>
                  <span style={{ fontSize: 13, fontWeight: 700, color: C.ink }}>$12,400 / $20,000</span>
                </div>
                <div style={{ height: 8, background: "#F4F6FB", borderRadius: 4 }}>
                  <div style={{ height: "100%", width: "62%", background: C.primary, borderRadius: 4 }} />
                </div>
                <p style={{ fontSize: 11, color: C.muted, marginTop: 4 }}>62% of monthly budget</p>
              </div>
              <div style={{ display: "flex", alignItems: "center", gap: 8, padding: "10px 12px", background: C.orangeLight, borderRadius: 12 }}>
                <Lock size={14} color={C.orange} />
                <span style={{ fontSize: 12, fontWeight: 600, color: C.orange }}>$1,200 held in escrow</span>
              </div>
            </Card>

            {/* Recent transactions */}
            <Card>
              <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 14 }}>
                <p style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 14, color: C.ink }}>Recent Payments</p>
                <button onClick={() => goTo("emp-wallet")} style={{ color: C.primary, fontSize: 12, fontWeight: 600 }}>See all</button>
              </div>
              {empTransactions.slice(0, 3).map(t => (
                <div key={t.id} style={{ display: "flex", alignItems: "center", gap: 10, paddingBottom: 10, marginBottom: 10, borderBottom: `1px solid ${C.border}` }}>
                  <div style={{ width: 34, height: 34, background: t.type === "credit" ? C.greenLight : t.type === "escrow" ? C.orangeLight : C.redLight, borderRadius: 10, display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
                    {t.type === "credit" ? <ArrowDownToLine size={15} color={C.green} /> : t.type === "escrow" ? <Lock size={15} color={C.orange} /> : <ArrowUpFromLine size={15} color={C.red} />}
                  </div>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <p style={{ fontSize: 12, fontWeight: 600, color: C.ink, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{t.desc}</p>
                    <p style={{ fontSize: 11, color: C.muted }}>{t.date}</p>
                  </div>
                  <span style={{ fontSize: 13, fontWeight: 700, color: t.type === "credit" ? C.green : t.type === "escrow" ? C.orange : C.red }}>{t.amount}</span>
                </div>
              ))}
            </Card>

            {/* Hired professionals */}
            <Card>
              <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 14 }}>
                <p style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 14, color: C.ink }}>Current Hires</p>
              </div>
              {professionals.slice(0, 3).map(p => (
                <div key={p.id} style={{ display: "flex", alignItems: "center", gap: 10, paddingBottom: 10, marginBottom: 10, borderBottom: `1px solid ${C.border}` }}>
                  <Av initials={p.avatar} color={p.color} size={34} />
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <p style={{ fontSize: 13, fontWeight: 700, color: C.ink, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{p.name}</p>
                    <p style={{ fontSize: 11, color: C.muted }}>{p.role}</p>
                  </div>
                  <button onClick={() => goTo("emp-chat")} style={{ width: 28, height: 28, background: C.primaryLight, borderRadius: 8, display: "flex", alignItems: "center", justifyContent: "center" }}><MessageCircle size={13} color={C.primary} /></button>
                </div>
              ))}
            </Card>
          </div>
        )}
      </div>
    </div>
  );
}

function EmpDiscover({ goTo, bp }: { goTo: (s: Screen) => void; bp: BP }) {
  const { isMobile, isDesktop } = bp;
  const [category, setCategory] = useState("All services");
  const categories = ["All services", "Development", "Design", "Skilled trades", "Data", "Content"];
  return (
    <div style={{ flex: 1, overflowY: "auto", padding: isMobile ? "16px 16px 80px" : "28px" }}>
      <div style={{ maxWidth: 1120, margin: "0 auto" }}>
        <div style={{ display: "flex", alignItems: "flex-end", justifyContent: "space-between", gap: 16, flexWrap: "wrap" }}>
          <div>
            <h2 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 24, color: C.ink }}>Find a Professional</h2>
            <p style={{ color: C.gray, fontSize: 14, marginTop: 4 }}>Discover verified people for digital and physical services.</p>
          </div>
          <Btn onClick={() => goTo("emp-postjob")} icon={<Plus size={15} />}>Post a Job</Btn>
        </div>
        <div style={{ display: "flex", gap: 10, marginTop: 22 }}>
          <div style={{ flex: 1, background: C.card, borderRadius: 13, border: `1px solid ${C.border}`, display: "flex", alignItems: "center", gap: 9, padding: "0 14px" }}>
            <Search size={17} color={C.muted} />
            <input placeholder="Search skills, services or professionals" style={{ width: "100%", padding: "13px 0", background: "transparent", border: 0, outline: 0, color: C.ink, fontSize: 13 }} />
          </div>
          <button style={{ background: C.card, border: `1px solid ${C.border}`, borderRadius: 13, padding: "0 14px", display: "flex", alignItems: "center", gap: 6, color: C.gray, fontSize: 12, fontWeight: 700 }}><Filter size={14} /> {!isMobile && "Filters"}</button>
        </div>
        <div style={{ display: "flex", gap: 8, overflowX: "auto", marginTop: 14, paddingBottom: 4 }}>
          {categories.map(item => <button key={item} onClick={() => setCategory(item)} style={{ padding: "8px 13px", borderRadius: 20, background: category === item ? C.primary : C.card, color: category === item ? "#fff" : C.gray, border: `1px solid ${category === item ? C.primary : C.border}`, fontSize: 12, fontWeight: 700, whiteSpace: "nowrap" }}>{item}</button>)}
        </div>
        <div style={{ display: "grid", gridTemplateColumns: isDesktop ? "repeat(3,1fr)" : isMobile ? "1fr" : "repeat(2,1fr)", gap: 14, marginTop: 20 }}>
          {professionals.map(pro => (
            <Card key={pro.id}>
              <div style={{ display: "flex", gap: 12, alignItems: "center" }}>
                <Av initials={pro.avatar} color={pro.color} size={48} />
                <div style={{ flex: 1, minWidth: 0 }}>
                  <div style={{ display: "flex", alignItems: "center", gap: 5 }}><p style={{ fontSize: 14, fontWeight: 800, color: C.ink }}>{pro.name}</p>{pro.verified && <Shield size={12} color={C.green} fill={C.greenLight} />}</div>
                  <p style={{ fontSize: 12, color: C.gray, marginTop: 2 }}>{pro.role}</p>
                  <Stars rating={pro.rating} reviews={pro.reviews} />
                </div>
                <Heart size={16} color={C.muted} />
              </div>
              <p style={{ fontSize: 12, color: C.gray, lineHeight: 1.55, marginTop: 13 }}>{pro.bio}</p>
              <div style={{ display: "flex", flexWrap: "wrap", gap: 5, marginTop: 11 }}>{pro.skills.slice(0, 3).map(skill => <Pill key={skill} label={skill} color={C.primary} bg={C.primaryLight} />)}</div>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginTop: 15, paddingTop: 13, borderTop: `1px solid ${C.border}` }}>
                <div><p style={{ fontSize: 13, fontWeight: 800, color: C.ink }}>{pro.rate}</p><p style={{ fontSize: 10, color: C.muted, marginTop: 2, display: "flex", alignItems: "center", gap: 3 }}><MapPin size={9} />{pro.location}</p></div>
                <div style={{ display: "flex", gap: 6 }}><Btn size="sm" variant="ghost" onClick={() => goTo("emp-chat")}>Message</Btn><Btn size="sm" onClick={() => goTo("emp-postjob")}>Hire</Btn></div>
              </div>
            </Card>
          ))}
        </div>
      </div>
    </div>
  );
}

function EmpPostJob({ goTo, bp }: { goTo: (s: Screen) => void; bp: BP }) {
  const { isDesktop, isMobile } = bp;
  const [jobType, setJobType] = useState<"Digital" | "Physical">("Digital");
  const [category, setCategory] = useState("Development");
  const [done, setDone] = useState(false);
  if (done) return (
    <div style={{ flex: 1, display: "flex", alignItems: "center", justifyContent: "center" }}>
      <div style={{ textAlign: "center", maxWidth: 400, padding: 32 }}>
        <div style={{ width: 88, height: 88, background: C.greenLight, borderRadius: 28, display: "flex", alignItems: "center", justifyContent: "center", margin: "0 auto 20px" }}><Check size={44} color={C.green} strokeWidth={2.5} /></div>
        <h2 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 26, color: C.ink, letterSpacing: -0.5, marginBottom: 10 }}>Job Posted!</h2>
        <p style={{ color: C.gray, fontSize: 16, lineHeight: 1.6, marginBottom: 24 }}>Your job is live. Professionals are already being matched to it.</p>
        <div style={{ display: "flex", gap: 12 }}><Btn onClick={() => setDone(false)} variant="secondary">Post Another</Btn><Btn onClick={() => goTo("emp-jobs")}>View My Jobs →</Btn></div>
      </div>
    </div>
  );
  return (
    <div style={{ flex: 1, overflowY: "auto", padding: isMobile ? "16px 16px 80px" : "28px" }}>
      <div style={{ maxWidth: 920, margin: "0 auto" }}>
        <div style={{ marginBottom: 24 }}>
          <h2 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 24, color: C.ink, letterSpacing: -0.5 }}>Post a New Job</h2>
          <p style={{ color: C.gray, fontSize: 15, marginTop: 4 }}>Find the right professional for your project</p>
        </div>
        <div style={{ display: "grid", gridTemplateColumns: isDesktop ? "1fr 340px" : "1fr", gap: 24 }}>
          <div style={{ display: "flex", flexDirection: "column", gap: 18 }}>
            <Card>
              <p style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 15, color: C.ink, marginBottom: 18 }}>Job Details</p>
              <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
                <Input label="Job Title *" placeholder="e.g. Senior React Developer Needed" defaultValue="Senior React Developer Needed" />
                <div>
                  <label style={{ fontSize: 13, fontWeight: 600, color: "#374151", display: "block", marginBottom: 7 }}>Service Type *</label>
                  <div style={{ display: "flex", gap: 10 }}>
                    {(["Digital", "Physical"] as const).map(t => (
                      <button key={t} onClick={() => setJobType(t)} style={{ flex: 1, padding: "13px", borderRadius: 12, fontWeight: 600, fontSize: 14, background: jobType === t ? C.primaryLight : "#F4F6FB", color: jobType === t ? C.primary : C.gray, border: `1.5px solid ${jobType === t ? C.primary : "transparent"}` }}>
                        {t === "Digital" ? "💻 Digital" : "🔧 Physical"}
                      </button>
                    ))}
                  </div>
                </div>
                <div>
                  <label style={{ fontSize: 13, fontWeight: 600, color: "#374151", display: "block", marginBottom: 7 }}>Category *</label>
                  <div style={{ display: "flex", flexWrap: "wrap", gap: 8 }}>
                    {["Development", "Design", "Trades", "Finance", "Teaching", "Care", "Data", "Energy"].map(c => (
                      <button key={c} onClick={() => setCategory(c)} style={{ padding: "7px 14px", borderRadius: 20, fontWeight: 600, fontSize: 12, background: category === c ? C.primary : "#F4F6FB", color: category === c ? "#fff" : C.gray }}>{c}</button>
                    ))}
                  </div>
                </div>
                <Input label="Description *" placeholder="Describe requirements, deliverables, and expectations..." rows={5} />
                <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }}>
                  <Input label="Required Skills" placeholder="React, TypeScript..." />
                  <div>
                    <label style={{ fontSize: 13, fontWeight: 600, color: "#374151", display: "block", marginBottom: 7 }}>Experience Level</label>
                    <select style={{ width: "100%", padding: "13px 14px", background: "#F4F6FB", borderRadius: 12, border: "1.5px solid transparent", fontSize: 14, outline: "none", boxSizing: "border-box", color: "#374151" }}>
                      <option>Any</option><option>Entry (0–2 yrs)</option><option>Mid (3–5 yrs)</option><option>Senior (5+ yrs)</option>
                    </select>
                  </div>
                </div>
              </div>
            </Card>
          </div>
          <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
            <Card>
              <p style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 15, color: C.ink, marginBottom: 16 }}>Budget & Timeline</p>
              <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
                <div>
                  <label style={{ fontSize: 13, fontWeight: 600, color: "#374151", display: "block", marginBottom: 7 }}>Budget *</label>
                  <div style={{ display: "flex", background: "#F4F6FB", borderRadius: 12, overflow: "hidden" }}>
                    <span style={{ padding: "13px 14px", color: "#374151", fontWeight: 700, borderRight: `1px solid ${C.border}` }}>$</span>
                    <input type="number" defaultValue="3500" style={{ flex: 1, padding: "13px 14px", background: "transparent", border: "none", fontSize: 15, outline: "none" }} />
                    <select style={{ padding: "13px 12px", background: "transparent", border: "none", fontSize: 13, outline: "none", color: C.gray }}><option>Fixed</option><option>Hourly</option></select>
                  </div>
                </div>
                <div>
                  <label style={{ fontSize: 13, fontWeight: 600, color: "#374151", display: "block", marginBottom: 7 }}>Location</label>
                  <div style={{ display: "flex", alignItems: "center", gap: 10, background: "#F4F6FB", borderRadius: 12, padding: "13px 14px" }}>
                    <MapPin size={15} color={C.muted} /><input defaultValue="Remote" style={{ flex: 1, background: "transparent", border: "none", fontSize: 14, outline: "none" }} />
                  </div>
                </div>
                <Input label="Deadline" type="date" defaultValue="2026-07-20" />
              </div>
            </Card>
            <div style={{ background: C.primaryLight, borderRadius: 16, padding: 18, display: "flex", gap: 10 }}>
              <Shield size={18} color={C.primary} style={{ flexShrink: 0, marginTop: 2 }} />
              <div><p style={{ fontWeight: 700, fontSize: 13, color: C.ink, marginBottom: 3 }}>Escrow Protection</p><p style={{ fontSize: 12, color: "#4B5563", lineHeight: 1.6 }}>Payment held securely until you approve the completed work.</p></div>
            </div>
            <Btn size="lg" onClick={() => setDone(true)} icon={<Zap size={17} fill="#fff" />}>Post Job Now</Btn>
          </div>
        </div>
      </div>
    </div>
  );
}

function EmpJobs({ goTo, bp }: { goTo: (s: Screen) => void; bp: BP }) {
  const { isDesktop, isMobile } = bp;
  const [filter, setFilter] = useState<"all" | "open" | "in-progress" | "completed">("all");
  const filtered = jobListings.filter(j => filter === "all" || j.status === filter);
  return (
    <div style={{ flex: 1, overflowY: "auto", padding: isMobile ? "16px 16px 80px" : "28px" }}>
      <div style={{ maxWidth: 1100, margin: "0 auto" }}>
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 24, flexWrap: "wrap", gap: 12 }}>
          <div><h2 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 22, color: C.ink }}>My Posted Jobs</h2><p style={{ fontSize: 14, color: C.gray, marginTop: 3 }}>{jobListings.length} jobs · {jobListings.filter(j => j.status === "open").length} open</p></div>
          <Btn onClick={() => goTo("emp-postjob")} icon={<Plus size={16} />}>Post New Job</Btn>
        </div>
        <div style={{ display: "flex", gap: 8, marginBottom: 20, flexWrap: "wrap" }}>
          {(["all", "open", "in-progress", "completed"] as const).map(f => (
            <button key={f} onClick={() => setFilter(f)} style={{ padding: "7px 16px", borderRadius: 20, fontSize: 12, fontWeight: 700, background: filter === f ? C.primary : C.card, color: filter === f ? "#fff" : C.gray, boxShadow: "0 1px 4px rgba(0,0,0,0.06)", transition: "all 0.2s" }}>
              {f === "all" ? "All Jobs" : f === "open" ? "Open" : f === "in-progress" ? "In Progress" : "Completed"}
            </button>
          ))}
        </div>
        <div style={{ display: "grid", gridTemplateColumns: isDesktop ? "1fr 1fr" : "1fr", gap: 14 }}>
          {filtered.map(j => (
            <JobRow key={j.id} job={j} extra={
              <div style={{ display: "flex", gap: 8, marginTop: 10, flexWrap: "wrap" }}>
                <Btn size="sm" onClick={() => goTo("emp-applications")} icon={<Users size={12} />}>{j.applicants} Applications</Btn>
                <Btn size="sm" variant="ghost" onClick={() => goTo("emp-chat")} icon={<MessageCircle size={12} />}>Chat</Btn>
                {j.status !== "completed" && <Btn size="sm" variant="danger" icon={<X size={12} />}>Close</Btn>}
              </div>
            } />
          ))}
        </div>
      </div>
    </div>
  );
}

function EmpApplications({ goTo, bp }: { goTo: (s: Screen) => void; bp: BP }) {
  const { isDesktop, isMobile } = bp;
  const [selectedJob, setSelectedJob] = useState(1);
  const jobApps = applications.filter(a => a.jobId === selectedJob);
  const job = jobListings.find(j => j.id === selectedJob)!;
  return (
    <div style={{ flex: 1, overflowY: "auto", padding: isMobile ? "16px 16px 80px" : "28px" }}>
      <div style={{ maxWidth: 1100, margin: "0 auto" }}>
        <div style={{ marginBottom: 24 }}>
          <h2 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 22, color: C.ink }}>Applications</h2>
          <p style={{ fontSize: 14, color: C.gray, marginTop: 3 }}>Review and manage applicants for your jobs</p>
        </div>
        <div style={{ display: "grid", gridTemplateColumns: isDesktop ? "260px 1fr" : "1fr", gap: 20, alignItems: "start" }}>
          {/* Job selector */}
          {isDesktop && (
            <Card>
              <p style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 13, color: C.muted, marginBottom: 12, textTransform: "uppercase", letterSpacing: 0.5 }}>Your Jobs</p>
              {jobListings.map(j => (
                <button key={j.id} onClick={() => setSelectedJob(j.id)} style={{ width: "100%", padding: "10px 12px", borderRadius: 11, background: selectedJob === j.id ? C.primaryLight : "transparent", textAlign: "left", marginBottom: 4, border: `1.5px solid ${selectedJob === j.id ? C.primary : "transparent"}`, transition: "all 0.15s" }}>
                  <p style={{ fontSize: 13, fontWeight: 700, color: selectedJob === j.id ? C.primary : C.ink, marginBottom: 2 }}>{j.title}</p>
                  <div style={{ display: "flex", gap: 6, alignItems: "center" }}>
                    <Pill label={`${applications.filter(a => a.jobId === j.id).length} apps`} color={C.primary} bg={C.primaryLight} />
                    <Pill label={j.status} color={j.status === "open" ? C.green : C.orange} bg={j.status === "open" ? C.greenLight : C.orangeLight} />
                  </div>
                </button>
              ))}
            </Card>
          )}

          {/* Applicants */}
          <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
            {!isDesktop && (
              <div>
                <label style={{ fontSize: 13, fontWeight: 600, color: "#374151", display: "block", marginBottom: 7 }}>Select Job</label>
                <select value={selectedJob} onChange={e => setSelectedJob(Number(e.target.value))} style={{ width: "100%", padding: "12px 14px", background: C.card, borderRadius: 12, border: `1px solid ${C.border}`, fontSize: 14, outline: "none" }}>
                  {jobListings.map(j => <option key={j.id} value={j.id}>{j.title}</option>)}
                </select>
              </div>
            )}

            <Card>
              <div style={{ display: "flex", alignItems: "center", gap: 10, marginBottom: 16, paddingBottom: 14, borderBottom: `1px solid ${C.border}` }}>
                <div style={{ flex: 1 }}>
                  <h3 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 16, color: C.ink }}>{job.title}</h3>
                  <p style={{ fontSize: 13, color: C.gray, marginTop: 3 }}>{jobApps.length} application{jobApps.length !== 1 ? "s" : ""} · {job.budget} budget</p>
                </div>
                <Pill label={job.status} color={job.status === "open" ? C.green : C.orange} bg={job.status === "open" ? C.greenLight : C.orangeLight} />
              </div>

              {jobApps.length === 0
                ? <div style={{ textAlign: "center", padding: "32px 0", color: C.muted }}><Users size={40} color={C.muted} style={{ margin: "0 auto 12px" }} /><p style={{ fontWeight: 600 }}>No applications yet for this job</p></div>
                : jobApps.map(app => (
                  <div key={app.id} style={{ padding: "16px 0", borderBottom: `1px solid ${C.border}` }}>
                    <div style={{ display: "flex", gap: 12, alignItems: "flex-start" }}>
                      <Av initials={app.pro.avatar} color={app.pro.color} size={48} />
                      <div style={{ flex: 1, minWidth: 0 }}>
                        <div style={{ display: "flex", alignItems: "flex-start", justifyContent: "space-between", gap: 8, marginBottom: 4 }}>
                          <div>
                            <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
                              <p style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 15, color: C.ink }}>{app.pro.name}</p>
                              {app.pro.verified && <Shield size={13} color={C.green} fill={C.green} />}
                            </div>
                            <p style={{ fontSize: 13, color: C.gray }}>{app.pro.role} · {app.pro.location}</p>
                          </div>
                          <Pill label={app.status} color={app.status === "hired" ? C.green : app.status === "shortlisted" ? C.primary : app.status === "rejected" ? C.red : C.orange} bg={app.status === "hired" ? C.greenLight : app.status === "shortlisted" ? C.primaryLight : app.status === "rejected" ? C.redLight : C.orangeLight} />
                        </div>
                        <div style={{ display: "flex", gap: 12, marginBottom: 8 }}>
                          <Stars rating={app.pro.rating} reviews={app.pro.reviews} />
                          <span style={{ fontSize: 12, fontWeight: 700, color: C.primary }}>{app.proposedRate}</span>
                          <span style={{ fontSize: 12, color: C.muted }}>{app.pro.jobs} jobs done</span>
                        </div>
                        <div style={{ background: "#F8F9FC", borderRadius: 10, padding: "10px 12px", marginBottom: 10 }}>
                          <p style={{ fontSize: 13, color: "#4B5563", lineHeight: 1.6 }}>{app.coverLetter}</p>
                        </div>
                        <div style={{ display: "flex", flexWrap: "wrap", gap: 6, marginBottom: 10 }}>
                          {app.pro.skills.map(s => <span key={s} style={{ fontSize: 11, fontWeight: 600, color: "#374151", background: "#F4F6FB", padding: "3px 8px", borderRadius: 6 }}>{s}</span>)}
                        </div>
                        <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
                          {app.status !== "hired" && app.status !== "rejected" && (
                            <Btn size="sm" icon={<Check size={13} />}>Hire</Btn>
                          )}
                          <Btn size="sm" variant="secondary" onClick={() => goTo("emp-chat")} icon={<MessageCircle size={13} />}>Message</Btn>
                          <Btn size="sm" variant="ghost">View Profile</Btn>
                          {app.status !== "rejected" && app.status !== "hired" && <Btn size="sm" variant="danger" icon={<X size={13} />}>Reject</Btn>}
                        </div>
                      </div>
                    </div>
                  </div>
                ))
              }
            </Card>
          </div>
        </div>
      </div>
    </div>
  );
}

function EmpWallet({ goTo, bp }: { goTo: (s: Screen) => void; bp: BP }) {
  const { isDesktop, isMobile } = bp;
  const [tab, setTab] = useState<"all" | "out" | "escrow">("all");
  const [statementOpen, setStatementOpen] = useState(false);
  const filtered = empTransactions.filter(t => tab === "all" || (tab === "out" && t.type === "debit") || (tab === "escrow" && t.type === "escrow"));
  return (
    <div style={{ flex: 1, overflowY: "auto", padding: isMobile ? "16px 16px 80px" : "28px" }}>
      <div style={{ maxWidth: 1000, margin: "0 auto" }}>
        <div style={{ display: "grid", gridTemplateColumns: isDesktop ? "1fr 1fr 1fr" : "1fr", gap: 16, marginBottom: 24 }}>
          <div style={{ background: "linear-gradient(135deg,#1A2AD4,#2D3FE7)", borderRadius: 22, padding: 28 }}>
            <p style={{ color: "rgba(255,255,255,0.65)", fontSize: 13, marginBottom: 4 }}>Company Balance</p>
            <p style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 36, color: "#fff", letterSpacing: -1, marginBottom: 2 }}>$8,600.00</p>
            <p style={{ color: "rgba(255,255,255,0.5)", fontSize: 12, marginBottom: 20 }}>≈ ₦13,720,000</p>
            <div style={{ display: "flex", gap: 10 }}>
              <button style={{ flex: 1, background: "#fff", borderRadius: 12, padding: "11px 8px", fontSize: 13, fontWeight: 700, color: C.primary, display: "flex", alignItems: "center", justifyContent: "center", gap: 6 }}><ArrowDownToLine size={14} />Fund</button>
              <button onClick={() => setStatementOpen(true)} style={{ flex: 1, background: "rgba(255,255,255,0.15)", borderRadius: 12, padding: "11px 8px", fontSize: 13, fontWeight: 700, color: "#fff", display: "flex", alignItems: "center", justifyContent: "center", gap: 6, border: "1px solid rgba(255,255,255,0.2)" }}><Eye size={14} />Statement</button>
            </div>
          </div>
          {isDesktop && (
            <>
              <div style={{ background: C.card, borderRadius: 22, padding: 24, boxShadow: "0 2px 12px rgba(0,0,0,0.06)", display: "flex", flexDirection: "column", gap: 14 }}>
                <div style={{ display: "flex", gap: 10, alignItems: "center" }}>
                  <div style={{ width: 42, height: 42, background: C.redLight, borderRadius: 13, display: "flex", alignItems: "center", justifyContent: "center" }}><ArrowUpFromLine size={20} color={C.red} /></div>
                  <div><p style={{ fontSize: 12, color: C.muted }}>Total Spent (MTD)</p><p style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 22, color: C.ink }}>$12,400</p></div>
                </div>
                <div style={{ height: 1, background: C.border }} />
                <div style={{ display: "flex", gap: 10, alignItems: "center" }}>
                  <div style={{ width: 42, height: 42, background: C.orangeLight, borderRadius: 13, display: "flex", alignItems: "center", justifyContent: "center" }}><Lock size={20} color={C.orange} /></div>
                  <div><p style={{ fontSize: 12, color: C.muted }}>In Escrow</p><p style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 22, color: C.ink }}>$1,200</p></div>
                </div>
              </div>
              <div style={{ background: C.card, borderRadius: 22, padding: 24, boxShadow: "0 2px 12px rgba(0,0,0,0.06)" }}>
                <p style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 14, color: C.ink, marginBottom: 12 }}>Spending by Category</p>
                {[["Development", 55, C.primary], ["Design", 25, C.purple], ["Physical", 20, C.orange]].map(([l, pct, col]) => (
                  <div key={l as string} style={{ marginBottom: 12 }}>
                    <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 5 }}>
                      <span style={{ fontSize: 12, color: C.gray }}>{l}</span>
                      <span style={{ fontSize: 12, fontWeight: 700, color: col as string }}>{pct}%</span>
                    </div>
                    <div style={{ height: 7, background: "#F4F6FB", borderRadius: 4 }}><div style={{ height: "100%", width: `${pct}%`, background: col as string, borderRadius: 4 }} /></div>
                  </div>
                ))}
              </div>
            </>
          )}
        </div>

        <div style={{ background: C.orangeLight, borderRadius: 16, padding: "14px 18px", border: `1px solid #FED7AA`, display: "flex", alignItems: "center", gap: 12, marginBottom: 20 }}>
          <div style={{ width: 40, height: 40, background: "#FFEDD5", borderRadius: 12, display: "flex", alignItems: "center", justifyContent: "center" }}><Lock size={18} color={C.orange} /></div>
          <div style={{ flex: 1 }}>
            <p style={{ fontWeight: 700, fontSize: 14, color: C.ink }}>Escrow Held — Office Renovation & Electrical</p>
            <p style={{ fontSize: 12, color: C.muted }}>Releases upon your approval · Lagos Properties Ltd</p>
          </div>
          <span style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 17, color: C.orange }}>$1,200</span>
        </div>

        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 14 }}>
          <h3 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 16, color: C.ink }}>Payment History</h3>
          <div style={{ display: "flex", gap: 6 }}>
            {(["all", "out", "escrow"] as const).map(t => (
              <button key={t} onClick={() => setTab(t)} style={{ padding: "6px 14px", borderRadius: 20, fontSize: 12, fontWeight: 600, background: tab === t ? C.primary : C.card, color: tab === t ? "#fff" : C.gray, transition: "all 0.2s" }}>
                {t === "all" ? "All" : t === "out" ? "Payments Made" : "Escrow"}
              </button>
            ))}
          </div>
        </div>
        <Card radius={20} padding={0}>
          {filtered.map((t, i) => (
            <div key={t.id} style={{ padding: "16px 20px", borderBottom: i < filtered.length - 1 ? `1px solid ${C.border}` : "none", display: "flex", gap: 14, alignItems: "center" }}>
              <div style={{ width: 44, height: 44, background: t.type === "credit" ? C.greenLight : t.type === "escrow" ? C.orangeLight : C.redLight, borderRadius: 13, display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
                {t.type === "credit" ? <ArrowDownToLine size={19} color={C.green} /> : t.type === "escrow" ? <Lock size={19} color={C.orange} /> : <ArrowUpFromLine size={19} color={C.red} />}
              </div>
              <div style={{ flex: 1 }}>
                <p style={{ fontWeight: 600, fontSize: 14, color: C.ink }}>{t.desc}</p>
                <p style={{ fontSize: 12, color: C.muted, marginTop: 2 }}>{t.date} · {t.job}</p>
              </div>
              <div style={{ textAlign: "right" }}>
                <p style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 15, color: t.type === "credit" ? C.green : t.type === "escrow" ? C.orange : C.red }}>{t.amount}</p>
                <Pill label={t.status} color={t.status === "held" ? C.orange : C.green} bg={t.status === "held" ? C.orangeLight : C.greenLight} />
              </div>
            </div>
          ))}
        </Card>
      </div>
      {statementOpen && <FinancialActionDialog mode="statement" context="Client payments" transactions={empTransactions} onClose={() => setStatementOpen(false)} />}
    </div>
  );
}

function EmpProfile({ goTo, bp }: { goTo: (s: Screen) => void; bp: BP }) {
  const { isDesktop, isMobile } = bp;
  return (
    <div style={{ flex: 1, overflowY: "auto", padding: isMobile ? "16px 16px 80px" : "28px" }}>
      <div style={{ maxWidth: 900, margin: "0 auto" }}>
        <div style={{ marginBottom: 24 }}>
          <h2 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 22, color: C.ink }}>Company Profile & Settings</h2>
        </div>
        <div style={{ display: "grid", gridTemplateColumns: isDesktop ? "1fr 280px" : "1fr", gap: 20 }}>
          <div style={{ display: "flex", flexDirection: "column", gap: 18 }}>
            <Card>
              <div style={{ display: "flex", alignItems: "center", gap: 16, marginBottom: 20 }}>
                <div style={{ width: 72, height: 72, background: C.primaryLight, borderRadius: 22, display: "flex", alignItems: "center", justifyContent: "center", position: "relative" }}>
                  <span style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 24, color: C.primary }}>TV</span>
                  <button style={{ position: "absolute", bottom: -4, right: -4, width: 22, height: 22, background: C.primary, borderRadius: "50%", display: "flex", alignItems: "center", justifyContent: "center" }}><Camera size={11} color="#fff" /></button>
                </div>
                <div>
                  <h3 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 20, color: C.ink }}>TechVentures Africa</h3>
                  <div style={{ display: "flex", alignItems: "center", gap: 8, marginTop: 4 }}>
                    <Shield size={14} color={C.green} fill={C.green} />
                    <span style={{ fontSize: 13, color: C.green, fontWeight: 600 }}>Verified Employer</span>
                    <span style={{ fontSize: 13, color: C.muted }}>· Member since 2022</span>
                  </div>
                </div>
              </div>
              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }}>
                <Input label="Company Name" defaultValue="TechVentures Africa" />
                <Input label="Industry" defaultValue="Financial Technology" />
                <Input label="Email" defaultValue="hr@techventures.ng" type="email" />
                <Input label="Phone" defaultValue="+234 801 234 5678" type="tel" />
                <Input label="Website" defaultValue="techventuresafrica.com" />
                <div>
                  <label style={{ fontSize: 13, fontWeight: 600, color: "#374151", display: "block", marginBottom: 7 }}>Company Size</label>
                  <select style={{ width: "100%", padding: "13px 14px", background: "#F4F6FB", borderRadius: 12, border: "1.5px solid transparent", fontSize: 14, outline: "none", boxSizing: "border-box" }}>
                    <option>11–50 employees</option><option>1–10</option><option>51–200</option><option>200+</option>
                  </select>
                </div>
              </div>
              <div style={{ marginTop: 14 }}><Input label="Company Description" placeholder="Tell professionals about your company..." rows={3} /></div>
              <div style={{ marginTop: 16 }}><Btn>Save Changes</Btn></div>
            </Card>

            <Card>
              <p style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 15, color: C.ink, marginBottom: 16 }}>Payment Methods</p>
              <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
                {[{ label: "GTBank — **** 4521", primary: true }, { label: "Paystack — Business Account", primary: false }].map(m => (
                  <div key={m.label} style={{ display: "flex", alignItems: "center", gap: 12, padding: "12px 14px", background: m.primary ? C.primaryLight : "#F4F6FB", borderRadius: 12, border: `1.5px solid ${m.primary ? C.primary : "transparent"}` }}>
                    <Wallet size={16} color={m.primary ? C.primary : C.gray} />
                    <span style={{ flex: 1, fontSize: 14, fontWeight: 500, color: C.ink }}>{m.label}</span>
                    {m.primary && <Pill label="Primary" color={C.primary} bg={C.primaryLight} />}
                  </div>
                ))}
                <button style={{ padding: "11px", border: `1.5px dashed ${C.border}`, borderRadius: 12, fontSize: 13, fontWeight: 600, color: C.muted, display: "flex", alignItems: "center", justifyContent: "center", gap: 6 }}><Plus size={15} />Add Payment Method</button>
              </div>
            </Card>
          </div>

          <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
            <Card>
              <p style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 14, color: C.ink, marginBottom: 14 }}>Account Stats</p>
              {[["Jobs Posted", "8"], ["Total Hires", "12"], ["Avg Job Value", "$1,550"], ["Rating as Employer", "4.7 ★"], ["Member Since", "Jan 2022"]].map(([l, v]) => (
                <div key={l} style={{ display: "flex", justifyContent: "space-between", paddingBottom: 10, marginBottom: 10, borderBottom: `1px solid ${C.border}` }}>
                  <span style={{ fontSize: 13, color: C.gray }}>{l}</span><span style={{ fontSize: 13, fontWeight: 700, color: C.ink }}>{v}</span>
                </div>
              ))}
            </Card>
            <Card>
              <p style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 14, color: C.ink, marginBottom: 14 }}>Preferences</p>
              {[["Email notifications", true], ["Job application alerts", true], ["SMS updates", false], ["Weekly digest", true]].map(([l, v]) => (
                <div key={l as string} style={{ display: "flex", alignItems: "center", justifyContent: "space-between", paddingBottom: 10, marginBottom: 10, borderBottom: `1px solid ${C.border}` }}>
                  <span style={{ fontSize: 13, color: C.ink }}>{l as string}</span>
                  <div style={{ width: 36, height: 20, background: v ? C.primary : "#CBD5E1", borderRadius: 10, position: "relative", cursor: "pointer" }}>
                    <div style={{ position: "absolute", top: 3, left: v ? 18 : 3, width: 14, height: 14, background: "#fff", borderRadius: "50%", transition: "left 0.2s" }} />
                  </div>
                </div>
              ))}
            </Card>
            <Btn variant="danger" icon={<LogOut size={15} />}>Sign Out</Btn>
          </div>
        </div>
      </div>
    </div>
  );
}

// ─── Professional Screens ─────────────────────────────────────────────────────

function ProHome({ goTo, bp }: { goTo: (s: Screen) => void; bp: BP }) {
  const { isDesktop, isTablet, isMobile } = bp;
  const p = isMobile ? "16px 16px 80px" : "28px";
  const activeJobs = jobListings.filter(j => j.status === "in-progress").slice(0, 4);
  return (
    <div style={{ flex: 1, overflowY: "auto", padding: p }}>
      <ActivityHero
        bp={bp}
        eyebrow="I WANT TO OFFER MY SERVICES"
        name="Amara Diallo"
        description={<>You have <strong style={{ color: "#fff" }}>5 active jobs</strong> and <strong style={{ color: "#fff" }}>$4,300</strong> in recognised earnings this month. Keep building your reputation and expertise.</>}
        image={activityHeroImages.services}
        imageAlt="Professional working with a laptop in a modern workspace"
        gradient="linear-gradient(125deg,#116530 0%,#16A34A 58%,#32B965 100%)"
        highlights={[{ value: "$4,300", label: "Earned (MTD)" }, { value: "5", label: "Active Jobs" }, { value: "4.9", label: "Rating" }, { value: "95", label: "Jobs Done" }]}
        marginBottom={24}
      />

      <div style={{ display: "grid", gridTemplateColumns: isDesktop ? "1fr 320px" : "1fr", gap: 24 }}>
        <div style={{ display: "flex", flexDirection: "column", gap: 22 }}>
          {isMobile && (
            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 12 }}>
              {[
                { label: "Earned (MTD)", value: "$4,300", sub: "recognised payments", icon: <DollarSign size={20} color={C.green} />, color: C.green, bg: C.greenLight },
                { label: "Active Jobs", value: "5", sub: "in progress", icon: <Briefcase size={20} color={C.primary} />, color: C.primary, bg: C.primaryLight },
                { label: "Profile Views", value: "148", sub: "this week", icon: <Eye size={20} color={C.orange} />, color: C.orange, bg: C.orangeLight },
                { label: "Success Rate", value: "98%", sub: "of jobs completed", icon: <Award size={20} color={C.purple} />, color: C.purple, bg: C.purpleLight },
              ].map(s => <StatCard key={s.label} {...s} />)}
            </div>
          )}

          {/* Quick Actions — carousel on mobile & tablet, 3-col grid on desktop */}
          <Section title="Quick Actions">
            {isDesktop ? (
              <div style={{ display: "grid", gridTemplateColumns: "repeat(3,1fr)", gap: 10 }}>
                {[
                  { icon: <Search size={20} color={C.green} />, label: "Find New Work", bg: C.greenLight, onClick: () => goTo("pro-discover") },
                  { icon: <MessageCircle size={20} color={C.primary} />, label: "Check Messages", bg: C.primaryLight, onClick: () => goTo("pro-chat") },
                  { icon: <ArrowUpFromLine size={20} color={C.orange} />, label: "Withdraw Earnings", bg: C.orangeLight, onClick: () => goTo("pro-earnings-overview") },
                ].map(a => (
                  <button key={a.label} onClick={a.onClick} style={{ background: C.card, borderRadius: 14, padding: "16px 12px", display: "flex", flexDirection: "column", alignItems: "center", gap: 9, boxShadow: "0 2px 10px rgba(0,0,0,0.05)", border: `1px solid ${C.border}`, cursor: "pointer", transition: "all 0.2s" }}
                    onMouseEnter={e => { e.currentTarget.style.transform = "translateY(-2px)"; }}
                    onMouseLeave={e => { e.currentTarget.style.transform = "none"; }}>
                    <div style={{ width: 44, height: 44, background: a.bg, borderRadius: 13, display: "flex", alignItems: "center", justifyContent: "center" }}>{a.icon}</div>
                    <span style={{ fontSize: 12, fontWeight: 600, color: "#374151", textAlign: "center" }}>{a.label}</span>
                  </button>
                ))}
              </div>
            ) : (
              <div style={{ position: "relative" }}>
                <div className="hide-scrollbar" style={{ display: "flex", gap: 12, overflowX: "auto", scrollSnapType: "x mandatory", WebkitOverflowScrolling: "touch", paddingBottom: 6, msOverflowStyle: "none" }}>
                  {[
                    { icon: <Search size={22} color={C.green} />, label: "Find New Work", bg: C.greenLight, onClick: () => goTo("pro-discover") },
                    { icon: <MessageCircle size={22} color={C.primary} />, label: "Check Messages", bg: C.primaryLight, onClick: () => goTo("pro-chat") },
                    { icon: <ArrowUpFromLine size={22} color={C.orange} />, label: "Withdraw Earnings", bg: C.orangeLight, onClick: () => goTo("pro-earnings-overview") },
                  ].map(a => (
                    <button key={a.label} onClick={a.onClick} style={{ flex: "0 0 calc((100% - 24px) / 2.5)", scrollSnapAlign: "start", background: C.card, borderRadius: 14, padding: "18px 12px", display: "flex", flexDirection: "column", alignItems: "center", gap: 10, boxShadow: "0 2px 10px rgba(0,0,0,0.05)", border: `1px solid ${C.border}`, cursor: "pointer" }}>
                      <div style={{ width: 48, height: 48, background: a.bg, borderRadius: 14, display: "flex", alignItems: "center", justifyContent: "center" }}>{a.icon}</div>
                      <span style={{ fontSize: 12, fontWeight: 600, color: "#374151", textAlign: "center", lineHeight: 1.3 }}>{a.label}</span>
                    </button>
                  ))}
                </div>
              </div>
            )}
          </Section>

          {/* Active jobs */}
          <Section title="Active Jobs" action="Manage all" onAction={() => goTo("pro-jobs")}>
            {activeJobs.length > 0 ? activeJobs.map(j => (
              <JobRow key={j.id} job={j} extra={
                <div style={{ display: "flex", gap: 8, marginTop: 10 }}>
                  <Btn size="sm" variant="secondary" onClick={() => goTo("pro-chat")} icon={<MessageCircle size={12} />}>Message Employer</Btn>
                  <Btn size="sm" variant="ghost">Submit Work</Btn>
                </div>
              } />
            )) : <div style={{ textAlign: "center", padding: "20px", color: C.muted, background: "#F8F9FC", borderRadius: 14 }}><p>No active jobs. <button onClick={() => goTo("pro-discover")} style={{ color: C.green, fontWeight: 600 }}>Browse opportunities →</button></p></div>}
          </Section>

          {/* Recommended jobs */}
          <Section title="Recommended For You" action="See all" onAction={() => goTo("pro-discover")}>
            {jobListings.filter(j => j.status === "open").slice(0, 3).map(j => (
              <div key={j.id} style={{ background: C.card, borderRadius: 16, padding: "16px 18px", border: `1px solid ${C.border}`, boxShadow: "0 1px 6px rgba(0,0,0,0.05)" }}>
                <div style={{ display: "flex", gap: 10, justifyContent: "space-between", marginBottom: 8 }}>
                  <div style={{ flex: 1 }}>
                    <div style={{ display: "flex", gap: 6, marginBottom: 6, flexWrap: "wrap" }}>
                      <Pill label={j.category} color={C.primary} bg={C.primaryLight} />
                      {j.urgency === "urgent" && <Pill label="Urgent" color={C.red} bg={C.redLight} />}
                    </div>
                    <h4 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 14, color: C.ink }}>{j.title}</h4>
                    <p style={{ fontSize: 12, color: C.gray, marginTop: 3 }}>{j.company} · {j.location}</p>
                  </div>
                  <span style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 16, color: C.green }}>{j.budget}</span>
                </div>
                <div style={{ display: "flex", gap: 8 }}>
                  <Btn size="sm" icon={<FileText size={12} />}>Apply Now</Btn>
                  <Btn size="sm" variant="ghost">Save</Btn>
                </div>
              </div>
            ))}
          </Section>
        </div>

        {isDesktop && (
          <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
            <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 10 }}>
              {[
                { label: "Earned (MTD)", value: "$8,280", sub: "+23%", icon: <DollarSign size={18} color={C.green} />, color: C.green, bg: C.greenLight },
                { label: "Active Jobs", value: "5", sub: "in progress", icon: <Briefcase size={18} color={C.primary} />, color: C.primary, bg: C.primaryLight },
                { label: "Profile Views", value: "148", sub: "this week", icon: <Eye size={18} color={C.orange} />, color: C.orange, bg: C.orangeLight },
                { label: "Success Rate", value: "98%", sub: "all time", icon: <Award size={18} color={C.purple} />, color: C.purple, bg: C.purpleLight },
              ].map(s => <StatCard key={s.label} {...s} />)}
            </div>

            <Card>
              <p style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 14, color: C.ink, marginBottom: 14 }}>Earnings Chart</p>
              <div style={{ display: "flex", alignItems: "flex-end", gap: 4, height: 80, marginBottom: 8 }}>
                {[30,55,40,70,58,80,65,90,72,85,60,95].map((v, i) => (
                  <div key={i} style={{ flex: 1, height: `${v}%`, background: i === 11 ? C.green : "#DCFCE7", borderRadius: "4px 4px 0 0" }} />
                ))}
              </div>
              <p style={{ fontSize: 12, color: C.muted }}>Last 12 months · +23% this month</p>
            </Card>

            <Card>
              <p style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 14, color: C.ink, marginBottom: 14 }}>Recent Earnings</p>
              {proEarnings.slice(0, 3).map(t => (
                <div key={t.id} style={{ display: "flex", alignItems: "center", gap: 10, paddingBottom: 10, marginBottom: 10, borderBottom: `1px solid ${C.border}` }}>
                  <div style={{ width: 34, height: 34, background: t.type === "credit" ? C.greenLight : t.type === "escrow" ? C.orangeLight : C.redLight, borderRadius: 10, display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
                    {t.type === "credit" ? <ArrowDownToLine size={15} color={C.green} /> : t.type === "escrow" ? <Lock size={15} color={C.orange} /> : <ArrowUpFromLine size={15} color={C.red} />}
                  </div>
                  <div style={{ flex: 1, minWidth: 0 }}>
                    <p style={{ fontSize: 12, fontWeight: 600, color: C.ink, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{t.desc}</p>
                    <p style={{ fontSize: 11, color: C.muted }}>{t.date}</p>
                  </div>
                  <span style={{ fontSize: 12, fontWeight: 700, color: t.type === "credit" ? C.green : t.type === "escrow" ? C.orange : C.red }}>{t.amount}</span>
                </div>
              ))}
            </Card>

            <Card>
              <p style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 14, color: C.ink, marginBottom: 12 }}>Profile Completeness</p>
              <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 6 }}>
                <span style={{ fontSize: 13, color: C.gray }}>85% complete</span>
                <span style={{ fontSize: 13, fontWeight: 700, color: C.green }}>Strong</span>
              </div>
              <div style={{ height: 8, background: "#F4F6FB", borderRadius: 4, marginBottom: 10 }}>
                <div style={{ height: "100%", width: "85%", background: C.green, borderRadius: 4 }} />
              </div>
              <p style={{ fontSize: 12, color: C.muted }}>Add portfolio items to reach 100%</p>
              <button onClick={() => goTo("pro-profile")} style={{ marginTop: 10, fontSize: 12, fontWeight: 700, color: C.green }}>Complete profile →</button>
            </Card>
          </div>
        )}
      </div>
    </div>
  );
}

function ProDiscover({ goTo, bp }: { goTo: (s: Screen) => void; bp: BP }) {
  const { isDesktop, isMobile } = bp;
  const [query, setQuery] = useState("");
  const [applying, setApplying] = useState<number | null>(null);
  const [applied, setApplied] = useState<number[]>([]);
  const filtered = jobListings.filter(j => j.status === "open" && (!query || j.title.toLowerCase().includes(query.toLowerCase()) || j.company.toLowerCase().includes(query.toLowerCase())));
  return (
    <div style={{ flex: 1, display: "flex", flexDirection: "column", overflow: "hidden" }}>
      <div style={{ padding: isMobile ? "14px" : "18px 28px", background: C.card, borderBottom: `1px solid ${C.border}`, flexShrink: 0 }}>
        <div style={{ display: "flex", gap: 10, maxWidth: 800 }}>
          <div style={{ flex: 1, display: "flex", alignItems: "center", gap: 10, background: "#F4F6FB", borderRadius: 13, padding: "11px 15px" }}>
            <Search size={16} color={C.muted} />
            <input value={query} onChange={e => setQuery(e.target.value)} placeholder="Search jobs by title, company, or skill..." style={{ flex: 1, background: "transparent", border: "none", outline: "none", fontSize: 14, color: C.ink }} />
            {query && <button onClick={() => setQuery("")}><X size={13} color={C.muted} /></button>}
          </div>
          <button style={{ height: 46, padding: "0 16px", background: C.green, borderRadius: 12, display: "flex", alignItems: "center", gap: 8, color: "#fff", fontWeight: 600, fontSize: 13 }}><Filter size={15} />{!isMobile && "Filter"}</button>
        </div>
        <p style={{ fontSize: 13, color: C.muted, marginTop: 10 }}>{filtered.length} opportunities available · Matched to your skills</p>
      </div>
      <div style={{ flex: 1, overflowY: "auto", padding: isMobile ? "14px 14px 80px" : "20px 28px" }}>
        <div style={{ display: "grid", gridTemplateColumns: isDesktop ? "1fr 1fr" : "1fr", gap: 14 }}>
          {filtered.map(j => (
            <div key={j.id} style={{ background: C.card, borderRadius: 18, padding: 20, boxShadow: "0 2px 10px rgba(0,0,0,0.05)", border: `1px solid ${C.border}` }}>
              <div style={{ display: "flex", gap: 10, justifyContent: "space-between", marginBottom: 10 }}>
                <div style={{ flex: 1 }}>
                  <div style={{ display: "flex", gap: 6, marginBottom: 7, flexWrap: "wrap" }}>
                    <Pill label={j.category} color={C.primary} bg={C.primaryLight} />
                    <Pill label={j.type} color={j.type === "Digital" ? C.cyan : C.orange} bg={j.type === "Digital" ? C.cyanLight : C.orangeLight} />
                    {j.urgency === "urgent" && <Pill label="Urgent" color={C.red} bg={C.redLight} />}
                  </div>
                  <h4 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 15, color: C.ink, lineHeight: 1.3 }}>{j.title}</h4>
                  <p style={{ fontSize: 13, color: C.gray, marginTop: 4 }}>{j.company}</p>
                </div>
                <div style={{ textAlign: "right", flexShrink: 0 }}>
                  <p style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 17, color: C.green }}>{j.budget}</p>
                  <p style={{ fontSize: 12, color: C.muted, marginTop: 2 }}>{j.applicants} applied</p>
                </div>
              </div>
              <p style={{ fontSize: 13, color: "#4B5563", lineHeight: 1.6, marginBottom: 12 }}>{j.desc}</p>
              <div style={{ display: "flex", gap: 10, alignItems: "center", marginBottom: 14, flexWrap: "wrap" }}>
                <span style={{ fontSize: 12, color: C.muted, display: "flex", alignItems: "center", gap: 3 }}><MapPin size={11} />{j.location}</span>
                <span style={{ fontSize: 12, color: C.muted, display: "flex", alignItems: "center", gap: 3 }}><Clock size={11} />{j.posted}</span>
              </div>
              <div style={{ display: "flex", gap: 8 }}>
                {applied.includes(j.id)
                  ? <div style={{ flex: 1, padding: "11px", background: C.greenLight, borderRadius: 12, display: "flex", alignItems: "center", justifyContent: "center", gap: 6 }}><CheckCircle size={15} color={C.green} /><span style={{ fontWeight: 700, fontSize: 14, color: C.green }}>Applied!</span></div>
                  : <button onClick={() => setApplying(j.id)} style={{ flex: 1, background: C.green, color: "#fff", fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 14, padding: "11px", borderRadius: 12, display: "flex", alignItems: "center", justifyContent: "center", gap: 6 }}><FileText size={15} />Apply Now</button>
                }
                <button style={{ width: 44, height: 44, background: "#F4F6FB", borderRadius: 12, display: "flex", alignItems: "center", justifyContent: "center" }}><Heart size={16} color={C.muted} /></button>
              </div>
            </div>
          ))}
        </div>
      </div>

      {/* Apply modal */}
      {applying !== null && (
        <div style={{ position: "fixed", inset: 0, background: "rgba(0,0,0,0.4)", zIndex: 100, display: "flex", alignItems: "flex-end", justifyContent: "center" }} onClick={() => setApplying(null)}>
          <div style={{ background: C.card, borderRadius: "24px 24px 0 0", padding: "24px 24px 40px", width: "100%", maxWidth: 560 }} onClick={e => e.stopPropagation()}>
            <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 20 }}>
              <h3 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 18, color: C.ink }}>Submit Application</h3>
              <button onClick={() => setApplying(null)} style={{ width: 30, height: 30, background: "#F4F6FB", borderRadius: 9, display: "flex", alignItems: "center", justifyContent: "center" }}><X size={15} /></button>
            </div>
            <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
              <Input label="Your Proposed Rate" placeholder="e.g. $45/hr or $2,500 fixed" />
              <Input label="Cover Letter" placeholder="Explain why you're the best fit for this role..." rows={4} />
              <Input label="Relevant Portfolio Link (optional)" placeholder="github.com/yourname or portfolio.com" />
              <button onClick={() => { setApplied(prev => [...prev, applying!]); setApplying(null); }} style={{ background: C.green, color: "#fff", fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 16, padding: "15px", borderRadius: 13, display: "flex", alignItems: "center", justifyContent: "center", gap: 8 }}><FileText size={17} />Submit Application</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}

function ProJobs({ goTo, bp }: { goTo: (s: Screen) => void; bp: BP }) {
  const { isDesktop, isMobile } = bp;
  const [tab, setTab] = useState<"active" | "applied" | "completed">("active");
  return (
    <div style={{ flex: 1, overflowY: "auto", padding: isMobile ? "16px 16px 80px" : "28px" }}>
      <div style={{ maxWidth: 1000, margin: "0 auto" }}>
        <div style={{ marginBottom: 24 }}><h2 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 22, color: C.ink }}>My Jobs</h2><p style={{ fontSize: 14, color: C.gray, marginTop: 3 }}>Track your active work and applications</p></div>
        <div style={{ display: "flex", gap: 4, background: C.card, borderRadius: 14, padding: 4, marginBottom: 20, boxShadow: "0 2px 8px rgba(0,0,0,0.05)", width: "fit-content" }}>
          {(["active", "applied", "completed"] as const).map(t => (
            <button key={t} onClick={() => setTab(t)} style={{ padding: "9px 20px", borderRadius: 11, fontSize: 13, fontWeight: 700, background: tab === t ? C.green : "transparent", color: tab === t ? "#fff" : C.gray, transition: "all 0.2s", textTransform: "capitalize" }}>{t}</button>
          ))}
        </div>

        {tab === "active" && (
          <div style={{ display: "grid", gridTemplateColumns: isDesktop ? "1fr 1fr" : "1fr", gap: 16 }}>
            {jobListings.filter(j => j.status === "in-progress").map(j => (
              <div key={j.id} style={{ background: C.card, borderRadius: 18, padding: 20, boxShadow: "0 2px 10px rgba(0,0,0,0.05)", border: `1.5px solid ${C.green}20` }}>
                <div style={{ display: "flex", gap: 8, marginBottom: 8 }}>
                  <Pill label="In Progress" color={C.orange} bg={C.orangeLight} />
                  <Pill label={j.category} color={C.primary} bg={C.primaryLight} />
                </div>
                <h4 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 15, color: C.ink, marginBottom: 4 }}>{j.title}</h4>
                <p style={{ fontSize: 13, color: C.gray, marginBottom: 14 }}>{j.company} · {j.budget}</p>
                <div style={{ marginBottom: 16 }}>
                  <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 6 }}>
                    <span style={{ fontSize: 12, color: C.gray }}>Milestone progress</span>
                    <span style={{ fontSize: 12, fontWeight: 700, color: C.green }}>60%</span>
                  </div>
                  <div style={{ height: 7, background: "#F4F6FB", borderRadius: 4 }}><div style={{ height: "100%", width: "60%", background: C.green, borderRadius: 4 }} /></div>
                </div>
                <div style={{ display: "flex", gap: 8 }}>
                  <Btn size="sm" variant="secondary" onClick={() => goTo("pro-chat")} icon={<MessageCircle size={12} />}>Chat</Btn>
                  <Btn size="sm" icon={<CheckCircle size={12} />}>Submit Work</Btn>
                </div>
              </div>
            ))}
          </div>
        )}

        {tab === "applied" && (
          <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
            {applications.slice(0, 4).map(app => (
              <div key={app.id} style={{ background: C.card, borderRadius: 16, padding: "16px 18px", border: `1px solid ${C.border}` }}>
                <div style={{ display: "flex", gap: 10, justifyContent: "space-between", alignItems: "flex-start" }}>
                  <div>
                    <h4 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 14, color: C.ink }}>{jobListings.find(j => j.id === app.jobId)?.title}</h4>
                    <p style={{ fontSize: 13, color: C.gray, marginTop: 3 }}>{jobListings.find(j => j.id === app.jobId)?.company} · Applied {app.appliedDate}</p>
                  </div>
                  <Pill label={app.status} color={app.status === "hired" ? C.green : app.status === "shortlisted" ? C.primary : app.status === "rejected" ? C.red : C.orange} bg={app.status === "hired" ? C.greenLight : app.status === "shortlisted" ? C.primaryLight : app.status === "rejected" ? C.redLight : C.orangeLight} />
                </div>
                <p style={{ fontSize: 12, color: C.muted, marginTop: 8 }}>Proposed: {app.proposedRate}</p>
                {app.status === "hired" && <div style={{ marginTop: 10 }}><Btn size="sm" onClick={() => goTo("pro-chat")} icon={<MessageCircle size={12} />}>Contact Employer</Btn></div>}
              </div>
            ))}
          </div>
        )}

        {tab === "completed" && (
          <div style={{ display: "grid", gridTemplateColumns: isDesktop ? "1fr 1fr" : "1fr", gap: 14 }}>
            {jobListings.filter(j => j.status === "completed").map((j, idx) => {
              const ratings = [5, 5, 4, 5, 5, 4, 5];
              const rating = ratings[idx % ratings.length];
              const datesAgo = ["3w ago", "1mo ago", "1mo ago", "6w ago", "2mo ago", "2mo ago", "7w ago"];
              const dateLabel = datesAgo[idx % datesAgo.length];
              return (
                <div key={j.id} style={{ background: C.card, borderRadius: 16, padding: "16px 18px", border: `1px solid ${C.border}` }}>
                  <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", marginBottom: 8 }}>
                    <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}><Pill label="Completed" color={C.green} bg={C.greenLight} /><Pill label={j.category} color={C.primary} bg={C.primaryLight} /></div>
                    <span style={{ fontSize: 11, color: C.muted, whiteSpace: "nowrap", marginLeft: 8 }}>{dateLabel}</span>
                  </div>
                  <h4 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 14, color: C.ink, marginBottom: 4 }}>{j.title}</h4>
                  <p style={{ fontSize: 13, color: C.gray, marginBottom: 10 }}>{j.company} · Earned <strong style={{ color: C.green }}>{j.budget}</strong></p>
                  <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
                    <div style={{ display: "flex", gap: 2, alignItems: "center" }}>
                      {[...Array(5)].map((_, i) => <Star key={i} size={13} fill={i < rating ? "#F59E0B" : "#E5E7EB"} color={i < rating ? "#F59E0B" : "#E5E7EB"} />)}
                      <span style={{ fontSize: 12, color: C.muted, marginLeft: 6 }}>Rated {rating}/5</span>
                    </div>
                    <span style={{ fontSize: 12, fontWeight: 600, color: C.green, background: C.greenLight, padding: "3px 10px", borderRadius: 20 }}>Paid</span>
                  </div>
                </div>
              );
            })}
          </div>
        )}
      </div>
    </div>
  );
}

function ProWallet({ goTo, bp }: { goTo: (s: Screen) => void; bp: BP }) {
  const { isDesktop, isMobile } = bp;
  const [tab, setTab] = useState<"all" | "in" | "out">("all");
  const [financialAction, setFinancialAction] = useState<"withdraw" | "statement" | null>(null);
  const filtered = proEarnings.filter(t => tab === "all" || (tab === "in" && t.type === "credit") || (tab === "out" && t.type === "debit"));
  return (
    <div style={{ flex: 1, overflowY: "auto", padding: isMobile ? "16px 16px 80px" : "28px" }}>
      <div style={{ maxWidth: 1000, margin: "0 auto" }}>
        <div style={{ display: "grid", gridTemplateColumns: isDesktop ? "1fr 1fr 1fr" : "1fr", gap: 16, marginBottom: 24 }}>
          <div style={{ background: "linear-gradient(135deg,#15803D,#16A34A)", borderRadius: 22, padding: 28 }}>
            <p style={{ color: "rgba(255,255,255,0.65)", fontSize: 13, marginBottom: 4 }}>Available Balance</p>
            <p style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 36, color: "#fff", letterSpacing: -1, marginBottom: 2 }}>$6,154.00</p>
            <p style={{ color: "rgba(255,255,255,0.5)", fontSize: 12, marginBottom: 20 }}>≈ ₦9,806,000</p>
            <div style={{ display: "flex", gap: 10 }}>
              <button onClick={() => setFinancialAction("withdraw")} style={{ flex: 1, background: "#fff", borderRadius: 12, padding: "11px 8px", fontSize: 13, fontWeight: 700, color: C.green, display: "flex", alignItems: "center", justifyContent: "center", gap: 6 }}><ArrowUpFromLine size={14} />Withdraw</button>
              <button onClick={() => setFinancialAction("statement")} style={{ flex: 1, background: "rgba(255,255,255,0.15)", borderRadius: 12, padding: "11px 8px", fontSize: 13, fontWeight: 700, color: "#fff", display: "flex", alignItems: "center", justifyContent: "center", gap: 6, border: "1px solid rgba(255,255,255,0.2)" }}><Eye size={14} />Statement</button>
            </div>
          </div>
          {isDesktop && (
            <>
              <div style={{ background: C.card, borderRadius: 22, padding: 24, boxShadow: "0 2px 12px rgba(0,0,0,0.06)", display: "flex", flexDirection: "column", gap: 14 }}>
                <div style={{ display: "flex", gap: 10, alignItems: "center" }}>
                  <div style={{ width: 42, height: 42, background: C.greenLight, borderRadius: 13, display: "flex", alignItems: "center", justifyContent: "center" }}><TrendingUp size={20} color={C.green} /></div>
                  <div><p style={{ fontSize: 12, color: C.muted }}>Total Earned (All Time)</p><p style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 22, color: C.ink }}>$28,900</p></div>
                </div>
                <div style={{ height: 1, background: C.border }} />
                <div style={{ display: "flex", gap: 10, alignItems: "center" }}>
                  <div style={{ width: 42, height: 42, background: C.orangeLight, borderRadius: 13, display: "flex", alignItems: "center", justifyContent: "center" }}><Lock size={20} color={C.orange} /></div>
                  <div><p style={{ fontSize: 12, color: C.muted }}>In Escrow (Pending)</p><p style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 22, color: C.ink }}>$2,800</p></div>
                </div>
              </div>
              <div style={{ background: C.card, borderRadius: 22, padding: 24, boxShadow: "0 2px 12px rgba(0,0,0,0.06)" }}>
                <p style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 14, color: C.ink, marginBottom: 12 }}>Monthly Earnings</p>
                <div style={{ display: "flex", alignItems: "flex-end", gap: 4, height: 80 }}>
                  {[30,55,40,70,58,80,65,90,72,85,60,95].map((v, i) => (
                    <div key={i} style={{ flex: 1, height: `${v}%`, background: i === 11 ? C.green : "#DCFCE7", borderRadius: "4px 4px 0 0" }} />
                  ))}
                </div>
                <p style={{ fontSize: 12, color: C.muted, marginTop: 8 }}>+23% vs last month</p>
              </div>
            </>
          )}
        </div>

        <div style={{ background: C.orangeLight, borderRadius: 16, padding: "14px 18px", border: `1px solid #FED7AA`, display: "flex", alignItems: "center", gap: 12, marginBottom: 20 }}>
          <div style={{ width: 40, height: 40, background: "#FFEDD5", borderRadius: 12, display: "flex", alignItems: "center", justifyContent: "center" }}><Lock size={18} color={C.orange} /></div>
          <div style={{ flex: 1 }}>
            <p style={{ fontWeight: 700, fontSize: 14, color: C.ink }}>Escrow Pending — Data Pipeline Architecture</p>
            <p style={{ fontSize: 12, color: C.muted }}>Releases when Fintech Solutions approves your delivery</p>
          </div>
          <span style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 17, color: C.orange }}>$2,800</span>
        </div>

        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 14 }}>
          <h3 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 16, color: C.ink }}>Earnings History</h3>
          <div style={{ display: "flex", gap: 6 }}>
            {(["all", "in", "out"] as const).map(t => (
              <button key={t} onClick={() => setTab(t)} style={{ padding: "6px 14px", borderRadius: 20, fontSize: 12, fontWeight: 600, background: tab === t ? C.green : C.card, color: tab === t ? "#fff" : C.gray, transition: "all 0.2s" }}>
                {t === "all" ? "All" : t === "in" ? "Earned" : "Withdrawn"}
              </button>
            ))}
          </div>
        </div>
        <Card radius={20} padding={0}>
          {filtered.map((t, i) => (
            <div key={t.id} style={{ padding: "16px 20px", borderBottom: i < filtered.length - 1 ? `1px solid ${C.border}` : "none", display: "flex", gap: 14, alignItems: "center" }}>
              <div style={{ width: 44, height: 44, background: t.type === "credit" ? C.greenLight : t.type === "escrow" ? C.orangeLight : C.redLight, borderRadius: 13, display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
                {t.type === "credit" ? <ArrowDownToLine size={19} color={C.green} /> : t.type === "escrow" ? <Lock size={19} color={C.orange} /> : <ArrowUpFromLine size={19} color={C.red} />}
              </div>
              <div style={{ flex: 1 }}>
                <p style={{ fontWeight: 600, fontSize: 14, color: C.ink }}>{t.desc}</p>
                <p style={{ fontSize: 12, color: C.muted, marginTop: 2 }}>{t.date}{t.job ? ` · ${t.job}` : ""}</p>
              </div>
              <div style={{ textAlign: "right" }}>
                <p style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 15, color: t.type === "credit" ? C.green : t.type === "escrow" ? C.orange : C.red }}>{t.amount}</p>
                <Pill label={t.status} color={t.status === "held" ? C.orange : C.green} bg={t.status === "held" ? C.orangeLight : C.greenLight} />
              </div>
            </div>
          ))}
        </Card>
      </div>
      {financialAction && <FinancialActionDialog mode={financialAction} context="Professional earnings" transactions={proEarnings} onClose={() => setFinancialAction(null)} />}
    </div>
  );
}

function ProProfile({ goTo, bp }: { goTo: (s: Screen) => void; bp: BP }) {
  const pro = professionals[0];
  const { isDesktop, isMobile } = bp;
  const [tab, setTab] = useState<"profile" | "portfolio" | "reviews" | "settings">("profile");
  return (
    <div style={{ flex: 1, overflowY: "auto", padding: isMobile ? "16px 16px 80px" : "28px" }}>
      <div style={{ maxWidth: 1000, margin: "0 auto" }}>
        {/* Header card */}
        <div style={{ background: C.card, borderRadius: 22, overflow: "hidden", boxShadow: "0 2px 12px rgba(0,0,0,0.06)", marginBottom: 20 }}>
          <div style={{ background: "linear-gradient(135deg,#15803D,#16A34A)", height: 110 }} />
          <div style={{ padding: "0 24px 24px", marginTop: -44 }}>
            <div style={{ display: "flex", alignItems: "flex-end", justifyContent: "space-between", marginBottom: 14 }}>
              <div style={{ position: "relative" }}>
                <Av initials={pro.avatar} color="#fff" size={80} />
                <button style={{ position: "absolute", bottom: 2, right: 2, width: 24, height: 24, background: C.green, borderRadius: "50%", border: "2px solid #fff", display: "flex", alignItems: "center", justifyContent: "center" }}><Camera size={12} color="#fff" /></button>
              </div>
              <div style={{ display: "flex", gap: 8, marginBottom: 4 }}>
                <Btn size="sm" variant="secondary" icon={<Edit3 size={13} />}>Edit</Btn>
                <Btn size="sm" icon={<Eye size={13} />}>Preview</Btn>
              </div>
            </div>
            <h2 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 22, color: C.ink }}>{pro.name}</h2>
            <p style={{ fontSize: 15, color: C.gray, marginBottom: 10 }}>{pro.role}</p>
            <div style={{ display: "flex", gap: 20, flexWrap: "wrap" }}>
              <div style={{ display: "flex", alignItems: "center", gap: 4 }}><Star size={13} fill="#F59E0B" color="#F59E0B" /><span style={{ fontSize: 13, fontWeight: 600 }}>{pro.rating}</span><span style={{ fontSize: 12, color: C.muted }}>({pro.reviews} reviews)</span></div>
              <span style={{ fontSize: 13, color: C.gray, display: "flex", alignItems: "center", gap: 4 }}><MapPin size={13} />{pro.location}</span>
              <span style={{ fontSize: 13, color: C.gray }}>{pro.jobs} jobs completed</span>
              <span style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 14, color: C.green }}>{pro.rate}</span>
              <span style={{ fontSize: 13, display: "flex", alignItems: "center", gap: 4, color: pro.available ? C.green : C.muted, fontWeight: 600 }}>
                <div style={{ width: 7, height: 7, borderRadius: "50%", background: pro.available ? C.green : C.muted }} />
                {pro.available ? "Available" : "Busy"}
              </span>
            </div>
          </div>
        </div>

        <div style={{ display: "flex", gap: 4, background: C.card, borderRadius: 14, padding: 4, marginBottom: 20, boxShadow: "0 2px 8px rgba(0,0,0,0.05)", width: "fit-content", overflowX: "auto" }}>
          {(["profile", "portfolio", "reviews", "settings"] as const).map(t => (
            <button key={t} onClick={() => setTab(t)} style={{ padding: "9px 18px", borderRadius: 11, fontSize: 13, fontWeight: 700, background: tab === t ? C.green : "transparent", color: tab === t ? "#fff" : C.gray, textTransform: "capitalize", transition: "all 0.2s", whiteSpace: "nowrap" }}>{t}</button>
          ))}
        </div>

        <div style={{ display: "grid", gridTemplateColumns: isDesktop && tab === "profile" ? "1fr 280px" : "1fr", gap: 20 }}>
          {tab === "profile" && (
            <>
              <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
                <Card>
                  <p style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 15, color: C.ink, marginBottom: 16 }}>Personal Information</p>
                  <div style={{ display: "grid", gridTemplateColumns: isMobile ? "1fr" : "1fr 1fr", gap: 12 }}>
                    <Input label="Full Name" defaultValue="Amara Diallo" />
                    <Input label="Professional Title" defaultValue="Full-Stack Developer" />
                    <Input label="Email" defaultValue="amara@email.com" type="email" />
                    <Input label="Phone" defaultValue="+234 801 234 5678" />
                    <Input label="Location" defaultValue="Lagos, Nigeria" />
                    <Input label="Hourly Rate (USD)" defaultValue="45" type="number" />
                  </div>
                  <div style={{ marginTop: 14 }}><Input label="Professional Bio" rows={3} defaultValue="7 years building scalable fintech and e-commerce platforms across Africa and Europe." /></div>
                  <div style={{ marginTop: 14 }}><Btn icon={<Check size={15} />}>Save Profile</Btn></div>
                </Card>
                <Card>
                  <p style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 15, color: C.ink, marginBottom: 14 }}>Skills & Expertise</p>
                  <div style={{ display: "flex", flexWrap: "wrap", gap: 8, marginBottom: 14 }}>
                    {["React", "Node.js", "TypeScript", "PostgreSQL", "AWS", "Docker", "GraphQL", "Next.js", "Redis", "Python"].map(s => (
                      <div key={s} style={{ display: "flex", alignItems: "center", gap: 6, background: C.primaryLight, borderRadius: 20, padding: "5px 10px 5px 12px" }}>
                        <span style={{ fontSize: 12, fontWeight: 600, color: C.primary }}>{s}</span>
                        <button style={{ width: 14, height: 14, background: C.primary + "30", borderRadius: "50%", display: "flex", alignItems: "center", justifyContent: "center" }}><X size={9} color={C.primary} /></button>
                      </div>
                    ))}
                    <button style={{ display: "flex", alignItems: "center", gap: 5, padding: "5px 12px", border: `1.5px dashed ${C.border}`, borderRadius: 20, fontSize: 12, fontWeight: 600, color: C.muted }}><Plus size={13} />Add Skill</button>
                  </div>
                </Card>
              </div>
              {isDesktop && (
                <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
                  <Card>
                    <p style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 14, color: C.ink, marginBottom: 14 }}>Profile Stats</p>
                    {[["Profile Completeness", "85%"], ["Total Reviews", pro.reviews], ["Avg Rating", `${pro.rating} / 5.0`], ["Jobs Completed", pro.jobs], ["Response Time", "< 2 hours"], ["Availability", "From Jul 8"]].map(([l, v]) => (
                      <div key={l} style={{ display: "flex", justifyContent: "space-between", paddingBottom: 9, marginBottom: 9, borderBottom: `1px solid ${C.border}` }}>
                        <span style={{ fontSize: 12, color: C.gray }}>{l}</span><span style={{ fontSize: 12, fontWeight: 700, color: C.ink }}>{v}</span>
                      </div>
                    ))}
                  </Card>
                  <Card>
                    <p style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 14, color: C.ink, marginBottom: 12 }}>Verification Status</p>
                    {[["Identity", true], ["Email", true], ["Phone", true], ["Bank Account", false]].map(([l, done]) => (
                      <div key={l as string} style={{ display: "flex", alignItems: "center", gap: 8, paddingBottom: 9, marginBottom: 9, borderBottom: `1px solid ${C.border}` }}>
                        <div style={{ width: 20, height: 20, background: (done as boolean) ? C.greenLight : "#F4F6FB", borderRadius: "50%", display: "flex", alignItems: "center", justifyContent: "center" }}>
                          {(done as boolean) ? <Check size={11} color={C.green} strokeWidth={3} /> : <X size={11} color={C.muted} />}
                        </div>
                        <span style={{ fontSize: 13, color: C.ink, flex: 1 }}>{l as string}</span>
                        {!(done as boolean) && <button style={{ fontSize: 11, fontWeight: 700, color: C.primary }}>Verify →</button>}
                      </div>
                    ))}
                  </Card>
                </div>
              )}
            </>
          )}

          {tab === "portfolio" && (
            <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
              <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
                <p style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 16, color: C.ink }}>Portfolio Items</p>
                <Btn size="sm" icon={<Plus size={14} />}>Add Project</Btn>
              </div>
              <div style={{ display: "grid", gridTemplateColumns: isDesktop ? "1fr 1fr 1fr" : "1fr 1fr", gap: 14 }}>
                {[{ title: "FinTrack Dashboard", cat: "React / Node.js", color: C.primary, bg: C.primaryLight }, { title: "AfriShop E-commerce", cat: "Next.js / PostgreSQL", color: C.green, bg: C.greenLight }, { title: "POS Mobile App", cat: "React Native / AWS", color: C.orange, bg: C.orangeLight }, { title: "Analytics Platform", cat: "Python / BigQuery", color: C.purple, bg: C.purpleLight }, { title: "Payroll API", cat: "Node.js / GraphQL", color: C.cyan, bg: C.cyanLight }, { title: "Logistics Tracker", cat: "TypeScript / Redis", color: C.red, bg: C.redLight }].map((p, i) => (
                  <div key={i} style={{ background: C.card, borderRadius: 16, overflow: "hidden", boxShadow: "0 2px 8px rgba(0,0,0,0.05)", border: `1px solid ${C.border}`, cursor: "pointer" }}>
                    <div style={{ height: 100, background: p.bg, display: "flex", alignItems: "center", justifyContent: "center" }}><Briefcase size={36} color={p.color} /></div>
                    <div style={{ padding: "12px 14px" }}>
                      <p style={{ fontWeight: 700, fontSize: 13, color: C.ink }}>{p.title}</p>
                      <p style={{ fontSize: 11, color: C.muted, marginTop: 3 }}>{p.cat}</p>
                    </div>
                  </div>
                ))}
              </div>
            </div>
          )}

          {tab === "reviews" && (
            <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
              {[{ name: "TechVentures Africa", r: 5, text: "Exceptional work. Amara delivered a production-ready fintech dashboard 2 weeks ahead of schedule.", time: "2 weeks ago", job: "React Developer" },
                { name: "StartupHub GH", r: 5, text: "Outstanding design intuition paired with clean code. Our product is 10x better because of Amara.", time: "1 month ago", job: "Brand Platform" },
                { name: "Fintech Solutions", r: 4, text: "Solid data pipeline implementation. A few iterations needed but overall great professionalism.", time: "2 months ago", job: "Data Pipeline" }].map((rv, i) => (
                  <Card key={i}>
                    <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 10 }}>
                      <div><p style={{ fontWeight: 700, fontSize: 14, color: C.ink }}>{rv.name}</p><p style={{ fontSize: 12, color: C.muted }}>{rv.job} · {rv.time}</p></div>
                      <div style={{ display: "flex", gap: 2 }}>{[...Array(5)].map((_, j) => <Star key={j} size={13} fill={j < rv.r ? "#F59E0B" : "#E5E7EB"} color={j < rv.r ? "#F59E0B" : "#E5E7EB"} />)}</div>
                    </div>
                    <p style={{ fontSize: 14, color: "#4B5563", lineHeight: 1.7 }}>{rv.text}</p>
                  </Card>
                ))}
            </div>
          )}

          {tab === "settings" && (
            <div style={{ display: "grid", gridTemplateColumns: isDesktop ? "1fr 1fr" : "1fr", gap: 16 }}>
              <Card>
                <p style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 15, color: C.ink, marginBottom: 16 }}>Availability</p>
                {[["Available for new work", true], ["Open to full-time roles", false], ["Open to part-time", true], ["Remote only", true]].map(([l, v]) => (
                  <div key={l as string} style={{ display: "flex", alignItems: "center", justifyContent: "space-between", paddingBottom: 12, marginBottom: 12, borderBottom: `1px solid ${C.border}` }}>
                    <span style={{ fontSize: 14, color: C.ink }}>{l as string}</span>
                    <div style={{ width: 38, height: 22, background: (v as boolean) ? C.green : "#CBD5E1", borderRadius: 11, position: "relative", cursor: "pointer" }}>
                      <div style={{ position: "absolute", top: 4, left: (v as boolean) ? 18 : 4, width: 14, height: 14, background: "#fff", borderRadius: "50%", transition: "left 0.2s" }} />
                    </div>
                  </div>
                ))}
              </Card>
              <Card>
                <p style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 15, color: C.ink, marginBottom: 16 }}>Notifications</p>
                {[["New job matches", true], ["Application updates", true], ["Payment received", true], ["Messages", true], ["Weekly summary", false]].map(([l, v]) => (
                  <div key={l as string} style={{ display: "flex", alignItems: "center", justifyContent: "space-between", paddingBottom: 12, marginBottom: 12, borderBottom: `1px solid ${C.border}` }}>
                    <span style={{ fontSize: 14, color: C.ink }}>{l as string}</span>
                    <div style={{ width: 38, height: 22, background: (v as boolean) ? C.green : "#CBD5E1", borderRadius: 11, position: "relative", cursor: "pointer" }}>
                      <div style={{ position: "absolute", top: 4, left: (v as boolean) ? 18 : 4, width: 14, height: 14, background: "#fff", borderRadius: "50%", transition: "left 0.2s" }} />
                    </div>
                  </div>
                ))}
              </Card>
              <Card>
                <p style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 15, color: C.ink, marginBottom: 16 }}>Payout Account</p>
                {[{ label: "GTBank — Savings **** 4521", primary: true }, { label: "Chipper Cash — @amara.diallo", primary: false }].map(m => (
                  <div key={m.label} style={{ display: "flex", alignItems: "center", gap: 12, padding: "11px 13px", background: m.primary ? C.greenLight : "#F4F6FB", borderRadius: 12, border: `1.5px solid ${m.primary ? C.green : "transparent"}`, marginBottom: 8 }}>
                    <Wallet size={15} color={m.primary ? C.green : C.gray} />
                    <span style={{ flex: 1, fontSize: 13, fontWeight: 500, color: C.ink }}>{m.label}</span>
                    {m.primary && <Pill label="Primary" color={C.green} bg={C.greenLight} />}
                  </div>
                ))}
                <button style={{ padding: "10px", border: `1.5px dashed ${C.border}`, borderRadius: 12, fontSize: 13, fontWeight: 600, color: C.muted, display: "flex", alignItems: "center", justifyContent: "center", gap: 6, width: "100%" }}><Plus size={14} />Add Payout Method</button>
              </Card>
              <div style={{ display: "flex", flexDirection: "column", gap: 10 }}>
                <Btn variant="danger" icon={<LogOut size={15} />}>Sign Out</Btn>
                <button style={{ padding: "12px", border: `1.5px solid ${C.border}`, borderRadius: 12, fontSize: 14, fontWeight: 600, color: C.red }}>Delete Account</button>
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

// ─── Admin Screens ────────────────────────────────────────────────────────────

function AdminOverview({ bp }: { bp: BP }) {
  const { isDesktop, isMobile } = bp;
  const kpis = [
    { label: "Total Users", value: "52,381", sub: "+12% MTD", icon: <Users size={20} color={C.primary} />, color: C.primary, bg: C.primaryLight },
    { label: "Active Jobs", value: "1,247", sub: "+8% MTD", icon: <Briefcase size={20} color={C.green} />, color: C.green, bg: C.greenLight },
    { label: "Revenue (MTD)", value: "$182K", sub: "+23% MTD", icon: <TrendingUp size={20} color={C.orange} />, color: C.orange, bg: C.orangeLight },
    { label: "Disputes", value: "14", sub: "-3 this week", icon: <AlertCircle size={20} color={C.red} />, color: C.red, bg: C.redLight },
    { label: "Escrow Held", value: "$84K", sub: "across 62 jobs", icon: <Lock size={20} color={C.purple} />, color: C.purple, bg: C.purpleLight },
    { label: "Avg Job Value", value: "$1,240", sub: "+15% MTD", icon: <Activity size={20} color={C.cyan} />, color: C.cyan, bg: C.cyanLight },
  ];
  return (
    <div style={{ flex: 1, overflowY: "auto", padding: isMobile ? "16px 16px 80px" : "28px" }}>
      <div style={{ maxWidth: 1200, margin: "0 auto" }}>
        <div style={{ marginBottom: 24 }}>
          <h2 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 22, color: C.ink }}>Platform Overview</h2>
          <p style={{ fontSize: 14, color: C.muted, marginTop: 3 }}>Hivorr Operations · July 7, 2026</p>
        </div>
        <div style={{ display: "grid", gridTemplateColumns: isDesktop ? "repeat(3,1fr)" : "1fr 1fr", gap: 14, marginBottom: 24 }}>
          {kpis.map(k => <StatCard key={k.label} {...k} />)}
        </div>
        <div style={{ display: "grid", gridTemplateColumns: isDesktop ? "2fr 1fr" : "1fr", gap: 20 }}>
          <Card>
            <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 20 }}>
              <h3 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 15, color: C.ink }}>Revenue — Last 14 Days</h3>
              <Pill label="+23% MTD" color={C.green} bg={C.greenLight} />
            </div>
            <div style={{ display: "flex", alignItems: "flex-end", gap: 5, height: 120 }}>
              {[40,55,38,70,62,88,75,50,66,80,58,90,72,95].map((v, i) => (
                <div key={i} style={{ flex: 1, display: "flex", flexDirection: "column", alignItems: "center", gap: 4 }}>
                  <div style={{ width: "100%", height: `${v}%`, background: i === 13 ? C.primary : i >= 10 ? "#A5B4FC" : C.primaryLight, borderRadius: "5px 5px 0 0" }} />
                  {i % 2 === 0 && <span style={{ fontSize: 9, color: C.muted }}>{i + 1}</span>}
                </div>
              ))}
            </div>
          </Card>
          <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
            <Card>
              <div style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 14 }}>
                <AlertCircle size={17} color={C.red} />
                <h4 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 14, color: C.ink }}>Flagged Items</h4>
                <span style={{ marginLeft: "auto", background: C.red, color: "#fff", fontSize: 11, fontWeight: 700, padding: "2px 7px", borderRadius: 8 }}>2</span>
              </div>
              {[{ title: "Cash-only plumbing work", r: "Off-platform payment", sev: "high" }, { title: "Incomplete job post", r: "Missing description", sev: "medium" }].map((f, i) => (
                <div key={i} style={{ background: "#F8F9FC", borderRadius: 11, padding: "10px 12px", marginBottom: i === 0 ? 8 : 0 }}>
                  <div style={{ display: "flex", justifyContent: "space-between", gap: 8 }}>
                    <div><p style={{ fontWeight: 600, fontSize: 12, color: C.ink }}>{f.title}</p><p style={{ fontSize: 11, color: C.muted, marginTop: 2 }}>{f.r}</p></div>
                    <Pill label={f.sev} color={f.sev === "high" ? C.red : C.orange} bg={f.sev === "high" ? C.redLight : C.orangeLight} />
                  </div>
                </div>
              ))}
            </Card>
            <Card>
              <h4 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 14, color: C.ink, marginBottom: 14 }}>Job Type Split</h4>
              {[["Digital", 68, C.primary], ["Physical", 32, C.orange]].map(([l, pct, col]) => (
                <div key={l as string} style={{ marginBottom: 12 }}>
                  <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 5 }}>
                    <span style={{ fontSize: 13, fontWeight: 600, color: "#374151" }}>{l}</span>
                    <span style={{ fontSize: 13, fontWeight: 700, color: col as string }}>{pct}%</span>
                  </div>
                  <div style={{ height: 7, background: "#F4F6FB", borderRadius: 4 }}><div style={{ height: "100%", width: `${pct}%`, background: col as string, borderRadius: 4 }} /></div>
                </div>
              ))}
            </Card>
          </div>
        </div>
      </div>
    </div>
  );
}

function AdminUsers({ bp }: { bp: BP }) {
  const { isDesktop, isMobile } = bp;
  const [users,setUsers] = useState([
    { name: "Amara Diallo", email: "amara@email.com", phone:"+234 803 555 0198", role: "Professional", status: "active", joined: "Jan 2024", jobs: 89,identity:"Verified",professional:"Approved",activity:"89 completed jobs · 4.9 rating",payments:"$42,180 earned",cases:"0 open reports" },
    { name: "TechVentures Africa", email: "hr@techventures.ng", phone:"+234 803 445 2180", role: "Employer", status: "active", joined: "Mar 2024", jobs: 32,identity:"Business verified",professional:"Not applicable",activity:"32 jobs posted · 8 active",payments:"$48,600 paid",cases:"1 resolved dispute" },
    { name: "Kwame Asante", email: "kwame@email.com", phone:"+233 24 881 4021", role: "Professional", status: "active", joined: "Apr 2024", jobs: 67,identity:"Verified",professional:"Approved",activity:"67 completed jobs · 4.8 rating",payments:"$31,240 earned",cases:"0 open reports" },
    { name: "Chidi Okonkwo", email: "chidi@email.com", phone:"+234 809 334 1042", role: "Professional", status: "pending", joined: "Jun 2024", jobs: 0,identity:"In review",professional:"Pending evidence",activity:"3 applications submitted",payments:"No transactions",cases:"0 reports" },
    { name: "Lagos Properties Ltd", email: "info@lagosprops.ng", phone:"+234 809 114 9072", role: "Employer", status: "suspended", joined: "Feb 2024", jobs: 12,identity:"Business verified",professional:"Not applicable",activity:"12 jobs posted · 0 active",payments:"$18,240 paid",cases:"2 open reports" },
    { name: "Fatima Hassan", email: "fatima@email.com", phone:"+254 712 440 890", role: "Professional", status: "active", joined: "Dec 2023", jobs: 156,identity:"Verified",professional:"Trade approved",activity:"156 completed jobs · 4.7 rating",payments:"$58,920 earned",cases:"1 resolved report" },
  ]);
  const [query,setQuery]=useState("");
  const [viewing,setViewing]=useState<(typeof users)[number]|null>(null);
  const [userAction,setUserAction]=useState<{name:string;action:"Approve"|"Reject"|"Suspend"|"Reinstate"|"Ban"|"Delete"}|null>(null);
  const [audit,setAudit]=useState("");
  const applyUserAction=()=>{
    if(!userAction)return;
    if(userAction.action==="Delete")setUsers(items=>items.filter(user=>user.name!==userAction.name));
    else setUsers(items=>items.map(user=>user.name===userAction.name?{...user,status:userAction.action==="Approve"||userAction.action==="Reinstate"?"active":userAction.action==="Ban"?"banned":"suspended"}:user));
    setAudit(`${userAction.action} recorded for ${userAction.name} by Super Admin · just now`);
    setViewing(null);
    setUserAction(null);
  };
  const filteredUsers=users.filter(user=>`${user.name} ${user.email} ${user.role} ${user.status}`.toLowerCase().includes(query.toLowerCase()));
  return (
    <div style={{ flex: 1, overflowY: "auto", padding: isMobile ? "16px 16px 80px" : "28px" }}>
      <div style={{ maxWidth: 1200, margin: "0 auto" }}>
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 24, flexWrap: "wrap", gap: 12 }}>
          <div><h2 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 22, color: C.ink }}>User Management</h2><p style={{ fontSize: 14, color: C.muted, marginTop: 3 }}>52,381 total users</p></div>
          <Btn size="sm" icon={<ArrowDownToLine size={14} />} variant="secondary" onClick={()=>setAudit("Sample user export prepared by Super Admin · just now")}>Export CSV</Btn>
        </div>
        <Card radius={20} padding={0}>
          <div style={{ padding: "14px 20px", borderBottom: `1px solid ${C.border}`, display: "flex", gap: 10 }}>
            <div style={{ flex: 1, display: "flex", alignItems: "center", gap: 8, background: "#F4F6FB", borderRadius: 11, padding: "9px 13px" }}>
              <Search size={14} color={C.muted} /><input value={query} onChange={event=>setQuery(event.target.value)} placeholder="Search users..." style={{ background: "transparent", border: "none", outline: "none", fontSize: 13,width:"100%" }} />
            </div>
          </div>
          <div style={{ overflowX: "auto" }}>
            <table style={{ width: "100%", borderCollapse: "collapse", minWidth: 600 }}>
              <thead>
                <tr style={{ background: "#F8F9FC" }}>
                  {["User", "Role", "Jobs", "Status", "Joined", "Actions"].map(h => (
                    <th key={h} style={{ padding: "12px 18px", textAlign: "left", fontSize: 12, fontWeight: 700, color: C.muted, whiteSpace: "nowrap" }}>{h}</th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {filteredUsers.map((u, i) => (
                  <tr key={i} style={{ borderBottom: `1px solid ${C.border}` }}>
                    <td style={{ padding: "14px 18px" }}>
                      <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
                        <Av initials={u.name.split(" ").map(n => n[0]).join("").slice(0, 2)} color={[C.primary, C.green, C.orange, C.purple, C.red, C.cyan][i]} size={34} />
                        <div><p style={{ fontWeight: 700, fontSize: 13, color: C.ink }}>{u.name}</p><p style={{ fontSize: 12, color: C.muted }}>{u.email}</p></div>
                      </div>
                    </td>
                    <td style={{ padding: "14px 18px" }}><Pill label={u.role} color={u.role === "Employer" ? C.primary : C.green} bg={u.role === "Employer" ? C.primaryLight : C.greenLight} /></td>
                    <td style={{ padding: "14px 18px", fontSize: 14, fontWeight: 600, color: "#374151" }}>{u.jobs}</td>
                    <td style={{ padding: "14px 18px" }}><span style={{ fontSize: 12, fontWeight: 700, color: u.status === "active" ? C.green : u.status === "pending" ? C.orange : C.red }}>● {u.status.charAt(0).toUpperCase() + u.status.slice(1)}</span></td>
                    <td style={{ padding: "14px 18px", fontSize: 13, color: C.muted }}>{u.joined}</td>
                    <td style={{ padding: "14px 18px" }}>
                      <div style={{ display: "flex", gap: 6 }}>
                        <Btn size="sm" variant="secondary" onClick={()=>setViewing(u)}>View</Btn>
                        {u.status === "pending" && <Btn size="sm" onClick={()=>setUserAction({name:u.name,action:"Approve"})}>Approve</Btn>}
                        {u.status === "suspended" ? <Btn size="sm" onClick={()=>setUserAction({name:u.name,action:"Reinstate"})}>Reinstate</Btn> : u.status!=="banned"&&<Btn size="sm" variant="danger" onClick={()=>setUserAction({name:u.name,action:u.status==="pending"?"Reject":"Suspend"})}>{u.status==="pending"?"Reject":"Suspend"}</Btn>}
                      </div>
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>
        </Card>
        {audit&&<div style={{ background:C.greenLight,borderRadius:11,padding:11,marginTop:10,display:"flex",gap:8 }}><CheckCircle size={15} color={C.green}/><p style={{ fontSize:10,color:C.green }}>{audit}</p></div>}
        {viewing&&<PrototypeDialog title={viewing.name} eyebrow="COMPREHENSIVE USER PROFILE" onClose={()=>setViewing(null)} maxWidth={720} footer={<><Btn variant="ghost" onClick={()=>setViewing(null)}>Close</Btn><Btn onClick={()=>setUserAction({name:viewing.name,action:viewing.status==="suspended"?"Reinstate":"Suspend"})}>{viewing.status==="suspended"?"Reinstate account":"Suspend account"}</Btn></>}><div style={{ display:"flex",flexDirection:"column",gap:13 }}><div style={{ display:"grid",gridTemplateColumns:bp.isMobile?"1fr":"1fr 1fr",gap:9 }}>{[["Email",viewing.email],["Phone",viewing.phone],["Account type",viewing.role],["Registration date",viewing.joined],["Identity verification",viewing.identity],["Professional verification",viewing.professional],["Account activity",viewing.activity],["Payment history",viewing.payments],["Reports / disputes",viewing.cases],["Current status",viewing.status]].map(([label,value])=><div key={label} style={{ background:"#F8F9FC",borderRadius:11,padding:11 }}><p style={{ fontSize:9,color:C.muted }}>{label}</p><p style={{ fontSize:11,fontWeight:700,color:C.ink,marginTop:3 }}>{value}</p></div>)}</div><div style={{ background:C.purpleLight,borderRadius:12,padding:12,display:"flex",gap:8 }}><Shield size={16} color={C.purple}/><p style={{ fontSize:10,color:C.gray,lineHeight:1.5 }}>Permission-controlled account actions are confirmed and recorded in the administrative audit trail.</p></div><div style={{ display:"flex",gap:6,flexWrap:"wrap" }}>{viewing.status==="suspended"&&<Btn size="sm" onClick={()=>setUserAction({name:viewing.name,action:"Reinstate"})}>Reinstate</Btn>}<Btn size="sm" variant="danger" onClick={()=>setUserAction({name:viewing.name,action:"Ban"})}>Ban account</Btn><Btn size="sm" variant="danger" onClick={()=>setUserAction({name:viewing.name,action:"Delete"})}>Delete account</Btn></div></div></PrototypeDialog>}
        {userAction&&<PrototypeDialog title={`${userAction.action} ${userAction.name}?`} eyebrow="ELEVATED ADMIN CONFIRMATION" onClose={()=>setUserAction(null)} footer={<><Btn variant="ghost" onClick={()=>setUserAction(null)}>Cancel</Btn><Btn variant={userAction.action==="Approve"||userAction.action==="Reinstate"?"primary":"danger"} onClick={applyUserAction}>Confirm {userAction.action.toLowerCase()}</Btn></>}><p style={{ fontSize:11,color:C.gray,lineHeight:1.6 }}>This permission-controlled action will update the prototype account and append an audit record with the administrator and timestamp.</p></PrototypeDialog>}
      </div>
    </div>
  );
}

function AdminJobs({ bp }: { bp: BP }) {
  const { isDesktop, isMobile } = bp;
  const [viewingJob,setViewingJob]=useState<(typeof jobListings)[number]|null>(null);
  const [removingJob,setRemovingJob]=useState<(typeof jobListings)[number]|null>(null);
  const [removedJobs,setRemovedJobs]=useState<number[]>([]);
  return (
    <div style={{ flex: 1, overflowY: "auto", padding: isMobile ? "16px 16px 80px" : "28px" }}>
      <div style={{ maxWidth: 1200, margin: "0 auto" }}>
        <div style={{ marginBottom: 24 }}><h2 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 22, color: C.ink }}>Job Moderation</h2><p style={{ fontSize: 14, color: C.muted, marginTop: 3 }}>{jobListings.length} total jobs · 2 flagged</p></div>
        <div style={{ display: "grid", gridTemplateColumns: isDesktop ? "1fr 1fr" : "1fr", gap: 14 }}>
          {jobListings.filter(job=>!removedJobs.includes(job.id)).map(j => (
            <div key={j.id} style={{ background: C.card, borderRadius: 18, padding: 20, boxShadow: "0 2px 8px rgba(0,0,0,0.05)" }}>
              <div style={{ display: "flex", gap: 8, justifyContent: "space-between", alignItems: "flex-start", marginBottom: 8 }}>
                <div style={{ flex: 1 }}>
                  <div style={{ display: "flex", gap: 6, marginBottom: 6 }}><Pill label={j.category} color={C.primary} bg={C.primaryLight} /><Pill label={j.type} color={j.type === "Digital" ? C.cyan : C.orange} bg={j.type === "Digital" ? C.cyanLight : C.orangeLight} /></div>
                  <h4 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 14, color: C.ink }}>{j.title}</h4>
                  <p style={{ fontSize: 12, color: C.gray, marginTop: 2 }}>{j.company} · {j.posted}</p>
                </div>
                <span style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 15, color: C.green }}>{j.budget}</span>
              </div>
              <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between" }}>
                <div style={{ display: "flex", gap: 8 }}>
                  <Pill label={j.status} color={j.status === "open" ? C.green : j.status === "in-progress" ? C.orange : C.muted} bg={j.status === "open" ? C.greenLight : j.status === "in-progress" ? C.orangeLight : "#F4F6FB"} />
                  <span style={{ fontSize: 12, color: C.muted }}>{j.applicants} applicants</span>
                </div>
                <div style={{ display: "flex", gap: 8 }}>
                  <Btn size="sm" icon={<Eye size={12} />} variant="ghost" onClick={()=>setViewingJob(j)}>View</Btn>
                  {j.status !== "completed" && <Btn size="sm" variant="danger" icon={<X size={12} />} onClick={()=>setRemovingJob(j)}>Remove</Btn>}
                </div>
              </div>
            </div>
          ))}
        </div>
        {viewingJob&&<PrototypeDialog title={viewingJob.title} eyebrow="JOB MODERATION DETAIL" onClose={()=>setViewingJob(null)} footer={<><Btn variant="ghost" onClick={()=>setViewingJob(null)}>Close</Btn><Btn variant="danger" onClick={()=>{setRemovingJob(viewingJob);setViewingJob(null);}}>Remove listing</Btn></>}><div style={{ display:"flex",flexDirection:"column",gap:13 }}><div style={{ display:"flex",gap:7,flexWrap:"wrap" }}><Pill label={viewingJob.category} color={C.primary} bg={C.primaryLight}/><Pill label={viewingJob.status} color={C.orange} bg={C.orangeLight}/></div><p style={{ fontSize:12,color:C.gray,lineHeight:1.6 }}>{viewingJob.desc}</p><div style={{ background:"#F8F9FC",borderRadius:12,padding:12 }}><p style={{ fontSize:11,fontWeight:700,color:C.ink }}>{viewingJob.company}</p><p style={{ fontSize:10,color:C.muted,marginTop:3 }}>{viewingJob.applicants} applicants · {viewingJob.budget}</p></div></div></PrototypeDialog>}
        {removingJob&&<PrototypeDialog title="Remove this job listing?" eyebrow="MODERATION CONFIRMATION" onClose={()=>setRemovingJob(null)} footer={<><Btn variant="ghost" onClick={()=>setRemovingJob(null)}>Cancel</Btn><Btn variant="danger" onClick={()=>{setRemovedJobs(items=>[...items,removingJob.id]);setRemovingJob(null);}}>Confirm removal</Btn></>}><div style={{ background:C.redLight,borderRadius:13,padding:13 }}><p style={{ fontSize:12,fontWeight:800,color:C.ink }}>{removingJob.title}</p><p style={{ fontSize:10,color:C.gray,lineHeight:1.5,marginTop:5 }}>The record will be hidden from this prototype moderation queue. A production action would be permission checked and audited.</p></div></PrototypeDialog>}
      </div>
    </div>
  );
}

function AdminPayments({ bp }: { bp: BP }) {
  const { isMobile } = bp;
  return (
    <div style={{ flex: 1, overflowY: "auto", padding: isMobile ? "16px 16px 80px" : "28px" }}>
      <div style={{ maxWidth: 1000, margin: "0 auto" }}>
        <div style={{ marginBottom: 24 }}><h2 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 22, color: C.ink }}>Payment Oversight</h2></div>
        <div style={{ display: "grid", gridTemplateColumns: isMobile ? "1fr" : "1fr 1fr 1fr", gap: 14, marginBottom: 24 }}>
          {[{ l: "Total Volume (MTD)", v: "$182K", c: C.primary, bg: C.primaryLight }, { l: "Escrow Held", v: "$84K", c: C.orange, bg: C.orangeLight }, { l: "Platform Revenue", v: "$5.4K", c: C.green, bg: C.greenLight }].map(s => (
            <Card key={s.l}><p style={{ fontSize: 12, color: C.muted, marginBottom: 4 }}>{s.l}</p><p style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 24, color: s.c }}>{s.v}</p></Card>
          ))}
        </div>
        <Card radius={20} padding={0}>
          <div style={{ padding: "14px 20px", borderBottom: `1px solid ${C.border}` }}><h3 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 15, color: C.ink }}>All Transactions</h3></div>
          {[...empTransactions, ...proEarnings].slice(0, 8).map((t, i, arr) => (
            <div key={t.id + i} style={{ padding: "14px 20px", borderBottom: i < arr.length - 1 ? `1px solid ${C.border}` : "none", display: "flex", gap: 12, alignItems: "center" }}>
              <div style={{ width: 40, height: 40, background: t.type === "credit" ? C.greenLight : t.type === "escrow" ? C.orangeLight : C.redLight, borderRadius: 12, display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}>
                {t.type === "credit" ? <ArrowDownToLine size={17} color={C.green} /> : t.type === "escrow" ? <Lock size={17} color={C.orange} /> : <ArrowUpFromLine size={17} color={C.red} />}
              </div>
              <div style={{ flex: 1 }}><p style={{ fontWeight: 600, fontSize: 13, color: C.ink }}>{t.desc}</p><p style={{ fontSize: 11, color: C.muted, marginTop: 2 }}>{t.date}</p></div>
              <div style={{ textAlign: "right" }}>
                <p style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 14, color: t.type === "credit" ? C.green : t.type === "escrow" ? C.orange : C.red }}>{t.amount}</p>
                <Pill label={t.status} color={t.status === "held" ? C.orange : C.green} bg={t.status === "held" ? C.orangeLight : C.greenLight} />
              </div>
            </div>
          ))}
        </Card>
      </div>
    </div>
  );
}

function AdminSettings({ bp }: { bp: BP }) {
  const { isDesktop, isMobile } = bp;
  const [section,setSection]=useState("Operations");
  const [toggles,setToggles]=useState<Record<string,boolean>>({"New user registrations":true,"Job posting":true,"Automatic identity approval":false,"Maintenance mode":false,"Email notifications":true,"Push notifications":true,"Withdrawal manual review":true});
  const [settingValues,setSettingValues]=useState({settlement:"weekly",withdrawal:"risk",professional:"manual",seller:"business"});
  const [confirmSave,setConfirmSave]=useState(false);
  const [saved,setSaved]=useState(false);
  const toggle=(label:string)=>setToggles(values=>({...values,[label]:!values[label]}));
  const toggleRows=(labels:string[])=>labels.map(label=><button key={label} onClick={()=>toggle(label)} style={{ width:"100%",display:"flex",alignItems:"center",justifyContent:"space-between",padding:"12px 0",borderBottom:`1px solid ${C.border}`,textAlign:"left" }}><span><span style={{ display:"block",fontSize:12,fontWeight:700,color:C.ink }}>{label}</span><span style={{ display:"block",fontSize:9,color:C.muted,marginTop:3 }}>{toggles[label]?"Enabled":"Disabled"} for the platform prototype</span></span><span style={{ width:38,height:22,background:toggles[label]?C.primary:"#CBD5E1",borderRadius:11,position:"relative" }}><span style={{ position:"absolute",top:4,left:toggles[label]?18:4,width:14,height:14,background:"#fff",borderRadius:"50%",transition:"left .2s" }}/></span></button>);
  return (
    <div style={{ flex: 1, overflowY: "auto", padding: isMobile ? "16px 16px 80px" : "28px" }}>
      <div style={{ maxWidth: 800, margin: "0 auto" }}>
        <div style={{ marginBottom: 20 }}><Pill label="PLATFORM ADMIN · CONFIGURATION" color={C.purple} bg={C.purpleLight}/><h2 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 22, color: C.ink,marginTop:8 }}>Platform Configuration</h2><p style={{ fontSize:11,color:C.gray,lineHeight:1.5,marginTop:4 }}>Authorised system-level controls for operations, verification, notifications and payment rules.</p></div>
        <div style={{ display:"flex",gap:6,overflowX:"auto",marginBottom:14 }}>{["Operations","Verification","Notifications","Payments"].map(item=><button key={item} onClick={()=>{setSection(item);setSaved(false);}} style={{ padding:"8px 12px",borderRadius:18,background:section===item?C.purple:C.card,color:section===item?"#fff":C.gray,fontSize:10,fontWeight:800,whiteSpace:"nowrap" }}>{item}</button>)}</div>
        <div style={{ display: "flex", flexDirection: "column", gap: 18 }}>
          {section==="Payments"&&<Card>
            <p style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 15, color: C.ink, marginBottom: 16 }}>Payment and settlement rules</p>
            <div style={{ display: "grid", gridTemplateColumns: isDesktop ? "1fr 1fr" : "1fr", gap: 12 }}>
              <Input label="Platform Fee (%)" defaultValue="3" type="number" />
              <Input label="Escrow Release Period (days)" defaultValue="3" type="number" />
              <Input label="Max Job Budget (USD)" defaultValue="50000" type="number" />
              <Input label="Min Job Budget (USD)" defaultValue="10" type="number" />
              <SelectField label="Default settlement schedule" value={settingValues.settlement} onChange={settlement=>setSettingValues(values=>({...values,settlement}))} options={[{value:"daily",label:"Daily"},{value:"weekly",label:"Weekly"},{value:"monthly",label:"Monthly"}]}/>
              <SelectField label="Withdrawal risk review" value={settingValues.withdrawal} onChange={withdrawal=>setSettingValues(values=>({...values,withdrawal}))} options={[{value:"risk",label:"Risk-based review"},{value:"all",label:"Review every withdrawal"}]}/>
            </div>
            <div style={{ marginTop:10 }}>{toggleRows(["Withdrawal manual review"])}</div>
          </Card>}
          {section==="Operations"&&<Card><p style={{ fontSize:15,fontWeight:800,color:C.ink }}>Platform operations</p><div style={{ marginTop:8 }}>{toggleRows(["New user registrations","Job posting","Maintenance mode"])}</div><div style={{ display:"grid",gridTemplateColumns:isDesktop?"1fr 1fr":"1fr",gap:12,marginTop:14 }}><Input label="Support response target (hours)" defaultValue="24" type="number"/><Input label="Default session timeout (minutes)" defaultValue="60" type="number"/></div></Card>}
          {section==="Verification"&&<Card><p style={{ fontSize:15,fontWeight:800,color:C.ink }}>Verification requirements</p><div style={{ marginTop:8 }}>{toggleRows(["Automatic identity approval"])}</div><div style={{ display:"grid",gridTemplateColumns:isDesktop?"1fr 1fr":"1fr",gap:12,marginTop:14 }}><SelectField label="Professional verification" value={settingValues.professional} onChange={professional=>setSettingValues(values=>({...values,professional}))} options={[{value:"manual",label:"Manual evidence review"},{value:"assisted",label:"Automated checks + manual review"}]}/><SelectField label="Seller verification" value={settingValues.seller} onChange={seller=>setSettingValues(values=>({...values,seller}))} options={[{value:"business",label:"Identity + business evidence"},{value:"identity",label:"Identity only"}]}/></div></Card>}
          {section==="Notifications"&&<Card><p style={{ fontSize:15,fontWeight:800,color:C.ink }}>Notification defaults</p><div style={{ marginTop:8 }}>{toggleRows(["Email notifications","Push notifications"])}</div><div style={{ display:"grid",gridTemplateColumns:isDesktop?"1fr 1fr":"1fr",gap:12,marginTop:14 }}><Input label="Sender name" defaultValue="Hivorr"/><Input label="Reply-to address" defaultValue="support@hivorr.com"/></div></Card>}
          <div style={{ display:"flex",justifyContent:"space-between",alignItems:"center" }}>{saved?<p style={{ fontSize:10,color:C.green,fontWeight:700 }}>Configuration saved to the prototype audit trail.</p>:<span/>}<Btn onClick={()=>setConfirmSave(true)}>Save {section} settings</Btn></div>
        </div>
        {confirmSave&&<PrototypeDialog title={`Save ${section.toLowerCase()} configuration?`} eyebrow="SUPER ADMIN CONFIRMATION" onClose={()=>setConfirmSave(false)} footer={<><Btn variant="ghost" onClick={()=>setConfirmSave(false)}>Cancel</Btn><Btn onClick={()=>{setConfirmSave(false);setSaved(true);}}>Confirm save</Btn></>}><p style={{ fontSize:11,color:C.gray,lineHeight:1.6 }}>This prototype will record the configuration change with your administrator identity and timestamp. No production settings are changed.</p></PrototypeDialog>}
      </div>
    </div>
  );
}

// ─── Unified Marketplace Experiences ─────────────────────────────────────────

function ProductCard({ product, onOpen, compact = false }: { product: typeof products[0]; onOpen: () => void; compact?: boolean }) {
  return (
    <button onClick={onOpen} style={{ background: C.card, borderRadius: compact ? 14 : 17, overflow: "hidden", border: `1px solid ${C.border}`, boxShadow: "0 2px 10px rgba(15,22,38,0.05)", textAlign: "left", minWidth: 0, cursor: "pointer" }}>
      <div style={{ height: compact ? 112 : 168, position: "relative", background: "#E9ECF5", overflow: "hidden" }}>
        <img src={product.image} alt={product.name} style={{ width: "100%", height: "100%", objectFit: "cover" }} />
        <span style={{ position: "absolute", top: compact ? 7 : 10, left: compact ? 7 : 10, background: "rgba(255,255,255,0.94)", color: C.ink, padding: compact ? "4px 6px" : "5px 8px", borderRadius: 8, fontSize: compact ? 8 : 10, fontWeight: 800 }}>{product.badge}</span>
        <div style={{ position: "absolute", top: compact ? 7 : 10, right: compact ? 7 : 10, width: compact ? 26 : 30, height: compact ? 26 : 30, borderRadius: "50%", background: "rgba(255,255,255,0.94)", display: "flex", alignItems: "center", justifyContent: "center" }}><Heart size={compact ? 12 : 14} color={C.gray} /></div>
      </div>
      <div style={{ padding: compact ? 10 : 14 }}>
        <p style={{ fontSize: compact ? 12 : 14, fontWeight: 700, lineHeight: 1.35, minHeight: compact ? 32 : "auto", color: C.ink, overflow: "hidden", textOverflow: "ellipsis", display: compact ? "-webkit-box" : "block", WebkitLineClamp: compact ? 2 : undefined, WebkitBoxOrient: compact ? "vertical" : undefined, whiteSpace: compact ? "normal" : "nowrap" }}>{product.name}</p>
        <p style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontSize: compact ? 14 : 16, fontWeight: 800, color: C.primary, marginTop: compact ? 3 : 5 }}>₦{product.price.toLocaleString()}</p>
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 5, marginTop: compact ? 6 : 9 }}>
          <span style={{ minWidth: 0, fontSize: compact ? 9 : 11, color: C.muted, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{product.seller}</span>
          <span style={{ display: "flex", gap: 3, alignItems: "center", flexShrink: 0, fontSize: compact ? 9 : 11, fontWeight: 700, color: C.ink }}><Star size={compact ? 9 : 10} fill="#F59E0B" color="#F59E0B" />{product.rating}</span>
        </div>
      </div>
    </button>
  );
}

type MarketFilterState = {
  categories: string[];
  price: string;
  availability: string[];
  sellers: string[];
  conditions: string[];
};

const emptyMarketFilters = (): MarketFilterState => ({ categories: [], price: "", availability: [], sellers: [], conditions: [] });

function MarketFilterPanel({ bp, filters, onChange, onApply, onReset, onClose }: { bp: BP; filters: MarketFilterState; onChange: (filters: MarketFilterState) => void; onApply: () => void; onReset: () => void; onClose: () => void }) {
  const toggle = (group: "categories" | "availability" | "sellers" | "conditions", value: string) => {
    const selected = filters[group].includes(value);
    onChange({ ...filters, [group]: selected ? filters[group].filter(item => item !== value) : [...filters[group], value] });
  };
  const option = (group: "categories" | "availability" | "sellers" | "conditions", value: string) => {
    const selected = filters[group].includes(value);
    return <button key={value} onClick={() => toggle(group, value)} style={{ minWidth: 0, padding: "9px 10px", borderRadius: 10, border: `1px solid ${selected ? C.primary : C.border}`, background: selected ? C.primaryLight : "#F8F9FC", color: selected ? C.primary : C.gray, fontSize: 11, fontWeight: selected ? 800 : 600, display: "flex", alignItems: "center", justifyContent: "space-between", gap: 6, textAlign: "left" }}><span style={{ overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{value}</span>{selected && <Check size={12} color={C.primary} />}</button>;
  };
  const priceOptions = ["₦5,000 – ₦20,000", "₦20,000 – ₦40,000", "₦40,000 – ₦75,000"];
  return <>
    <button aria-label="Close filters" onClick={onClose} style={{ position: "fixed", inset: 0, zIndex: 54, background: bp.isMobile ? "rgba(15,22,38,.42)" : "transparent" }} />
    <div role="dialog" aria-modal="true" aria-label="Product filters" style={{ position: bp.isMobile ? "fixed" : "absolute", zIndex: 55, left: bp.isMobile ? 10 : "auto", right: bp.isMobile ? 10 : 0, bottom: bp.isMobile ? 0 : "auto", top: bp.isMobile ? "auto" : 44, width: bp.isMobile ? "auto" : 430, maxHeight: bp.isMobile ? "82vh" : "min(680px,calc(100vh - 150px))", overflowY: "auto", background: C.card, border: `1px solid ${C.border}`, borderRadius: bp.isMobile ? "22px 22px 0 0" : 18, boxShadow: "0 22px 60px rgba(15,22,38,.22)", padding: bp.isMobile ? "18px 16px calc(18px + env(safe-area-inset-bottom,0px))" : 20 }}>
      <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 12 }}>
        <div><h2 style={{ fontSize: 17, fontWeight: 800, color: C.ink }}>Filter products</h2><p style={{ fontSize: 11, color: C.muted, marginTop: 3 }}>Choose one or more relevant options</p></div>
        <button aria-label="Close filter panel" onClick={onClose} style={{ width: 32, height: 32, borderRadius: 10, background: "#F4F6FB", display: "flex", alignItems: "center", justifyContent: "center", flexShrink: 0 }}><X size={16} color={C.gray} /></button>
      </div>
      <div style={{ display: "flex", flexDirection: "column", gap: 18, marginTop: 18 }}>
        <section><p style={{ fontSize: 12, fontWeight: 800, color: C.ink, marginBottom: 9 }}>Categories</p><div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 8 }}>{marketCategories.filter(category => category.label !== "More").map(category => option("categories", category.label))}</div></section>
        <section><p style={{ fontSize: 12, fontWeight: 800, color: C.ink, marginBottom: 9 }}>Price range</p><div style={{ display: "grid", gridTemplateColumns: bp.isMobile ? "1fr" : "repeat(3,1fr)", gap: 8 }}>{priceOptions.map(value => { const selected = filters.price === value; return <button key={value} onClick={() => onChange({ ...filters, price: selected ? "" : value })} style={{ padding: "9px 10px", borderRadius: 10, border: `1px solid ${selected ? C.primary : C.border}`, background: selected ? C.primaryLight : "#F8F9FC", color: selected ? C.primary : C.gray, fontSize: 10, fontWeight: selected ? 800 : 600 }}>{value}</button>; })}</div></section>
        <section><p style={{ fontSize: 12, fontWeight: 800, color: C.ink, marginBottom: 9 }}>Availability</p><div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 8 }}>{["In stock", "Low stock"].map(value => option("availability", value))}</div></section>
        <section><p style={{ fontSize: 12, fontWeight: 800, color: C.ink, marginBottom: 9 }}>Seller</p><div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 8 }}>{[...new Set(products.map(product => product.seller))].map(value => option("sellers", value))}</div></section>
        <section><p style={{ fontSize: 12, fontWeight: 800, color: C.ink, marginBottom: 9 }}>Condition</p><div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 8 }}>{["New", "Verified listing"].map(value => option("conditions", value))}</div></section>
      </div>
      <div style={{ position: "sticky", bottom: bp.isMobile ? "calc(-18px - env(safe-area-inset-bottom,0px))" : -20, background: C.card, display: "grid", gridTemplateColumns: "1fr 1.35fr", gap: 9, margin: "20px -4px -4px", padding: "12px 4px 4px", borderTop: `1px solid ${C.border}` }}><Btn variant="ghost" onClick={onReset}>Reset</Btn><Btn onClick={onApply} icon={<Check size={14} />}>Apply Filters</Btn></div>
    </div>
  </>;
}

type ActivityNavItem = { label: string; screen: Screen; icon: LucideIcon };

function activityNavActive(screen: Screen, item: ActivityNavItem) {
  return screen === item.screen
    || (item.screen === "market-browse" && screen === "product-detail")
    || (item.screen === "orders" && ["order-detail", "order-confirmation"].includes(screen))
    || (item.screen === "seller-products" && screen === "seller-listing")
    || (item.screen === "errand-request" && screen === "errand-review");
}

type ActivityMobileDestination = { screen: Screen; label: string; isPrimary?: boolean };

function ActivityMobileBottomNav({ screen, nav, destinations, color, goTo }: { screen: Screen; nav: ActivityNavItem[]; destinations: ActivityMobileDestination[]; color: string; goTo: (s: Screen) => void }) {
  const items: MobileNavEntry[] = destinations.flatMap(destination => {
    const item = nav.find(navItem => navItem.screen === destination.screen);
    return item ? [{ key: destination.screen, icon: item.icon, label: destination.label, screen: destination.screen, isPrimary: destination.isPrimary }] : [];
  });
  const exactActive = items.find(item => item.screen === screen);
  const relatedActive = exactActive ?? items.find(item => {
    const navItem = nav.find(candidate => candidate.screen === item.screen);
    return navItem ? activityNavActive(screen, navItem) : false;
  });
  return <MobileNavBar items={items} activeKey={relatedActive?.key} color={color} goTo={goTo} />;
}

function ActivitySidebar({ screen, nav, label, color, initials, name, collapsed, goTo, onClose }: { screen: Screen; nav: ActivityNavItem[]; label: string; color: string; initials: string; name: string; collapsed: boolean; goTo: (s: Screen) => void; onClose?: () => void }) {
  return <aside style={{ width: collapsed ? 66 : 224, flexShrink: 0, background: C.card, borderRight: `1px solid ${C.border}`, display: "flex", flexDirection: "column", height: "100vh", overflow: "hidden" }}>
    <div style={{ padding: collapsed ? "20px 14px" : "20px 18px", borderBottom: `1px solid ${C.border}`, display: "flex", alignItems: "center", gap: 10 }}>
      <div style={{ width: 32, height: 32, background: C.primary, borderRadius: 9, flexShrink: 0, display: "flex", alignItems: "center", justifyContent: "center" }}><Zap size={17} color="#fff" fill="#fff" /></div>
      {!collapsed && <span style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 17, color: C.ink, whiteSpace: "nowrap", flex: 1 }}>Hivorr</span>}
      {!collapsed && onClose && <button onClick={onClose} style={{ width: 30, height: 30, borderRadius: 9, background: "#F4F6FB", display: "flex", alignItems: "center", justifyContent: "center" }}><X size={15} color={C.gray} /></button>}
    </div>
    {!collapsed && <div style={{ padding: "12px 14px", borderBottom: `1px solid ${C.border}`, background: color + "0A" }}><div style={{ display: "flex", alignItems: "center", gap: 8 }}><div style={{ width: 8, height: 8, background: color, borderRadius: "50%" }} /><span style={{ fontSize: 12, fontWeight: 700, color }}>{label}</span></div></div>}
    <nav style={{ flex: 1, padding: collapsed ? "10px 9px" : "10px", display: "flex", flexDirection: "column", gap: 2, overflowY: "auto" }}>
      {nav.map(item => {
        const active = activityNavActive(screen, item);
        const Icon = item.icon;
        return <button key={item.label} title={collapsed ? item.label : undefined} onClick={() => { goTo(item.screen); onClose?.(); }} style={{ display: "flex", alignItems: "center", gap: 10, padding: collapsed ? "10px 11px" : "10px 12px", borderRadius: 11, background: active ? color + "18" : "transparent", color: active ? color : C.gray, fontWeight: 600, fontSize: 13, width: "100%", justifyContent: collapsed ? "center" : "flex-start", whiteSpace: "nowrap" }} onMouseEnter={e => { if (!active) e.currentTarget.style.background = "#F4F6FB"; }} onMouseLeave={e => { if (!active) e.currentTarget.style.background = "transparent"; }}><Icon size={17} color={active ? color : C.gray} />{!collapsed && item.label}</button>;
      })}
    </nav>
    <div style={{ padding: collapsed ? "12px 9px" : "12px", paddingBottom: "calc(12px + env(safe-area-inset-bottom, 0px))", borderTop: `1px solid ${C.border}` }}>
      <div style={{ display: "flex", alignItems: "center", gap: 10 }}><Av initials={initials} color={color} size={32} />{!collapsed && <div style={{ flex: 1, minWidth: 0 }}><p style={{ fontSize: 13, fontWeight: 700, color: C.ink, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{name}</p><p style={{ fontSize: 11, color: C.muted }}>{label}</p></div>} {!collapsed && <LogOut size={15} color={C.muted} />}</div>
    </div>
  </aside>;
}

function MarketShell({ screen, goTo, cartCount, children }: { screen: Screen; goTo: (s: Screen) => void; cartCount: number; children: React.ReactNode }) {
  const bp = useBreakpoint();
  const [drawerOpen, setDrawerOpen] = useState(false);
  const contentRef = useRef<HTMLDivElement>(null);
  useEffect(() => {
    if (bp.isMobile) contentRef.current?.scrollTo({ top: 0 });
  }, [screen, bp.isMobile]);
  const logisticsScreens: Screen[] = ["logistics-home", "logistics-requests", "logistics-active", "logistics-history", "logistics-earnings-overview", "logistics-earnings", "logistics-account-profile", "logistics-profile"];
  const errandScreens: Screen[] = ["errand-home", "errand-request", "errand-review", "errand-tracking", "errand-history", "errand-payments", "errand-profile"];
  const sellerScreens: Screen[] = ["seller-home", "seller-products", "seller-listing", "seller-orders", "seller-invoices", "seller-inventory", "seller-analytics", "seller-earnings", "seller-profile"];
  const isLogisticsProvider = logisticsScreens.includes(screen);
  const isErrand = errandScreens.includes(screen);
  const isSeller = sellerScreens.includes(screen);
  const isCommerce = !isLogisticsProvider && !isErrand && !isSeller;
  const nav: ActivityNavItem[] = isLogisticsProvider ? [
    { label: "Overview", screen: "logistics-home", icon: Home }, { label: "Available Requests", screen: "logistics-requests", icon: Search }, { label: "Active Assignments", screen: "logistics-active", icon: Navigation }, { label: "Delivery History", screen: "logistics-history", icon: Clock }, { label: "Earnings", screen: "logistics-earnings-overview", icon: Wallet }, { label: "Analysis", screen: "logistics-earnings", icon: BarChart2 }, { label: "Profile", screen: "logistics-account-profile", icon: User }, { label: "Provider Details", screen: "logistics-profile", icon: Shield },
  ] : isErrand ? [
    { label: "Errand Home", screen: "errand-home", icon: Home }, { label: "Create Errand", screen: "errand-request", icon: Plus }, { label: "My Errands", screen: "errand-history", icon: ClipboardList }, { label: "Active Tracking", screen: "errand-tracking", icon: Navigation }, { label: "Payments", screen: "errand-payments", icon: Wallet }, { label: "Profile", screen: "errand-profile", icon: User },
  ] : isSeller ? [
    { label: "Overview", screen: "seller-home", icon: Home }, { label: "Products", screen: "seller-products", icon: Store }, { label: "Add Product", screen: "seller-listing", icon: Plus }, { label: "Orders", screen: "seller-orders", icon: Package }, { label: "Inventory", screen: "seller-inventory", icon: Boxes }, { label: "Invoices", screen: "seller-invoices", icon: FileText }, { label: "Sales Analysis", screen: "seller-analytics", icon: BarChart2 }, { label: "Earnings", screen: "seller-earnings", icon: Wallet }, { label: "Profile", screen: "seller-profile", icon: User },
  ] : [
    { label: "Market Home", screen: "market-home", icon: Home }, { label: "Browse Products", screen: "market-browse", icon: Search }, { label: "Saved Products", screen: "market-saved", icon: Heart }, { label: "Cart", screen: "cart", icon: ShoppingCart }, { label: "My Orders", screen: "orders", icon: Package }, { label: "Payments", screen: "market-payments", icon: Wallet }, { label: "Profile", screen: "market-profile", icon: User },
  ];
  const color = isLogisticsProvider ? C.green : isErrand ? C.orange : isSeller ? C.purple : C.primary;
  const label = isLogisticsProvider ? "Logistics Provider" : isErrand ? "Errand Dashboard" : isSeller ? "Seller Dashboard" : "Local Market";
  const initials = isLogisticsProvider ? "KA" : isSeller ? "ZC" : "AD";
  const name = isLogisticsProvider ? "Kemi Adisa" : isSeller ? "Zuri Craft House" : "Amara Diallo";
  const mobileDestinations: ActivityMobileDestination[] = isLogisticsProvider ? [
    { screen: "logistics-home", label: "Overview" },
    { screen: "logistics-requests", label: "Requests" },
    { screen: "logistics-active", label: "Active" },
    { screen: "logistics-history", label: "History" },
    { screen: "logistics-earnings-overview", label: "Earnings" },
  ] : isErrand ? [
    { screen: "errand-home", label: "Home" },
    { screen: "errand-history", label: "Errands" },
    { screen: "errand-request", label: "New Errand", isPrimary: true },
    { screen: "errand-tracking", label: "Track" },
    { screen: "errand-payments", label: "Payments" },
  ] : isSeller ? [
    { screen: "seller-home", label: "Overview" },
    { screen: "seller-products", label: "Products" },
    { screen: "seller-listing", label: "Add Product", isPrimary: true },
    { screen: "seller-orders", label: "Orders" },
    { screen: "seller-earnings", label: "Earnings" },
  ] : [
    { screen: "market-home", label: "Market" },
    { screen: "market-browse", label: "Browse" },
    { screen: "market-saved", label: "Saved" },
    { screen: "orders", label: "Orders" },
    { screen: "market-profile", label: "Profile" },
  ];
  return <div style={{ display: "flex", height: "100vh", overflow: "hidden", background: C.bg }}>
    {!bp.isMobile && <ActivitySidebar screen={screen} nav={nav} label={label} color={color} initials={initials} name={name} collapsed={bp.isTablet} goTo={goTo} />}
    {bp.isMobile && drawerOpen && <><div onClick={() => setDrawerOpen(false)} style={{ position: "fixed", inset: 0, background: "rgba(0,0,0,.42)", zIndex: 50 }} /><div style={{ position: "fixed", inset: "0 auto 0 0", width: 260, zIndex: 51 }}><ActivitySidebar screen={screen} nav={nav} label={label} color={color} initials={initials} name={name} collapsed={false} goTo={goTo} onClose={() => setDrawerOpen(false)} /></div></>}
    <div style={{ flex: 1, minWidth: 0, display: "flex", flexDirection: "column", overflow: "hidden" }}>
      <header style={{ height: 62, flexShrink: 0, background: C.card, borderBottom: `1px solid ${C.border}`, display: "flex", alignItems: "center", justifyContent: "space-between", padding: bp.isMobile ? "0 14px" : "0 20px", zIndex: 30 }}>
        <div style={{ display: "flex", alignItems: "center", gap: 11 }}>{bp.isMobile && <button onClick={() => setDrawerOpen(true)} style={{ width: 36, height: 36, background: "#F4F6FB", borderRadius: 10, display: "flex", alignItems: "center", justifyContent: "center" }}><Menu size={17} color={C.gray} /></button>}<span style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 700, fontSize: 16, color: C.ink }}>{TITLES[screen]}</span></div>
        <div style={{ display: "flex", gap: 8, alignItems: "center" }}>
          <button onClick={() => goTo("role-select")} style={{ height: 36, borderRadius: 10, background: color + "12", display: "flex", alignItems: "center", gap: 6, padding: "0 10px", color, fontSize: 11, fontWeight: 700 }}><RotateCcw size={15} color={color} />{!bp.isMobile && "Activities"}</button>
          <button style={{ width: 36, height: 36, borderRadius: 10, background: "#F4F6FB", display: "flex", alignItems: "center", justifyContent: "center", position: "relative" }}><Bell size={16} color={C.gray} /><span style={{ position: "absolute", top: 7, right: 7, width: 6, height: 6, borderRadius: "50%", background: C.red }} /></button>
          {isCommerce && <button onClick={() => goTo("cart")} style={{ width: 36, height: 36, borderRadius: 10, background: C.primaryLight, display: "flex", alignItems: "center", justifyContent: "center", position: "relative" }}><ShoppingCart size={17} color={C.primary} />{cartCount > 0 && <span style={{ position: "absolute", top: -4, right: -4, width: 17, height: 17, borderRadius: "50%", background: C.red, color: "#fff", fontSize: 9, fontWeight: 800, display: "flex", alignItems: "center", justifyContent: "center", border: "2px solid #fff" }}>{cartCount}</span>}</button>}
          <button onClick={() => goTo(isLogisticsProvider ? "logistics-account-profile" : isSeller ? "seller-profile" : isErrand ? "errand-profile" : "market-profile")}><Av initials={initials} color={color} size={34} /></button>
        </div>
      </header>
      <div ref={contentRef} style={{ flex: 1, overflowY: "auto", overflowX: "hidden", scrollPaddingBottom: "calc(72px + env(safe-area-inset-bottom, 0px))" }}>{children}</div>
    </div>
    {bp.isMobile && <ActivityMobileBottomNav screen={screen} nav={nav} destinations={mobileDestinations} color={color} goTo={goTo} />}
  </div>;
}

const sharedPayments = [
  { activity: "market", ref: "PAY-84291", date: "Today, 10:42", desc: "Local Market · Order #HV-20481", amount: "-₦21,000", amountValue: -21000, status: "Paid", color: C.green, bg: C.greenLight },
  { activity: "client", ref: "PAY-84276", date: "Jul 15", desc: "Professional service · React Developer escrow", amount: "-₦1,200,000", amountValue: -1200000, status: "Held", color: C.orange, bg: C.orangeLight },
  { activity: "errand", ref: "PAY-84263", date: "Jul 14", desc: "Errand #ER-1042 authorization", amount: "-₦3,600", amountValue: -3600, status: "Pending", color: C.orange, bg: C.orangeLight },
  { activity: "market", ref: "REF-11842", date: "Jul 10", desc: "Local Market refund · Order #HV-20391", amount: "+₦14,500", amountValue: 14500, status: "Processing", color: C.primary, bg: C.primaryLight },
];

const sharedEarnings = [
  { activity: "professional", activityLabel: "Professional Services", desc: "Senior React Developer milestone", date: "Today", amount: "₦560,000", amountValue: 560000, status: "Available", withdrawable: true, color: C.green, bg: C.greenLight },
  { activity: "seller", activityLabel: "Product Sales", desc: "Order #HV-20472", date: "Yesterday", amount: "₦32,000", amountValue: 32000, status: "Pending settlement", withdrawable: false, color: C.orange, bg: C.orangeLight },
  { activity: "logistics", activityLabel: "Logistics", desc: "Delivery #DL-8388", date: "Jul 15", amount: "₦2,800", amountValue: 2800, status: "Available", withdrawable: true, color: C.green, bg: C.greenLight },
  { activity: "professional", activityLabel: "Professional Services", desc: "Data Pipeline escrow", date: "Jul 14", amount: "₦448,000", amountValue: 448000, status: "Pending", withdrawable: false, color: C.orange, bg: C.orangeLight },
];

type PaymentActivity = "market" | "client" | "errand";
const BASE_AVAILABLE_WALLET_BALANCE = 38400;
const availableEarningsBalance = sharedEarnings
  .filter(transaction => transaction.status === "Available")
  .reduce((total, transaction) => total + transaction.amountValue, 0);
const pendingWalletBalance = sharedPayments
  .filter(transaction => ["Held", "Pending", "Processing"].includes(transaction.status))
  .reduce((total, transaction) => total + Math.abs(transaction.amountValue), 0)
  + sharedEarnings
    .filter(transaction => transaction.status !== "Available")
    .reduce((total, transaction) => total + transaction.amountValue, 0);
const availableWalletBalance = BASE_AVAILABLE_WALLET_BALANCE + availableEarningsBalance;
const withdrawableWalletBalance = sharedEarnings
  .filter(transaction => transaction.withdrawable)
  .reduce((total, transaction) => total + transaction.amountValue, 0);
const formatNaira = (amount: number) => `₦${amount.toLocaleString("en-NG")}`;
const SHARED_WALLET = {
  available: formatNaira(availableWalletBalance),
  pending: formatNaira(pendingWalletBalance),
  withdrawable: formatNaira(withdrawableWalletBalance),
  total: formatNaira(availableWalletBalance + pendingWalletBalance),
};
const paymentLabels: Record<PaymentActivity, string> = { market: "Local Market", client: "Hiring", errand: "Errand" };
const paymentStats: Record<PaymentActivity, Array<[string, string]>> = {
  market: [["Product payments", "₦21,000"], ["Refunds", "₦14,500"], ["Orders", "2"]],
  client: [["Service payments", "₦1.20m"], ["Refunds", "₦0"], ["Hires paid", "1"]],
  errand: [["Errand charges", "₦3,600"], ["Refunds", "₦0"], ["Requests paid", "1"]],
};

const walletExplanations = {
  total: "This is the total money recorded in your Hivorr wallet across all your activities, including money that is available and money temporarily held.",
  available: "This is the money you can currently use to make payments or withdraw, subject to Hivorr's applicable rules.",
  pending: "This is money that belongs to you but is temporarily unavailable. It may become available when the relevant order, service, delivery, or transaction meets Hivorr's payment requirements.",
  withdrawable: "This is the amount currently eligible for withdrawal, subject to Hivorr's verification and settlement requirements.",
};

function WalletInfo({ label, explanation, isMobile, inverted = false }: { label: string; explanation: string; isMobile: boolean; inverted?: boolean }) {
  const [open, setOpen] = useState(false);
  const tooltipId = `wallet-info-${label.toLowerCase().replace(/\s+/g, "-")}`;
  return <span
    style={{ display: "inline-flex", alignItems: "center", gap: isMobile ? 3 : 5, position: "relative", minWidth: 0, lineHeight: 1.2 }}
    onMouseEnter={() => { if (!isMobile) setOpen(true); }}
    onMouseLeave={() => { if (!isMobile) setOpen(false); }}
  >
    <span style={{ minWidth: 0 }}>{label}</span>
    <button
      type="button"
      aria-label={`About ${label}`}
      aria-expanded={open}
      aria-describedby={open ? tooltipId : undefined}
      onClick={() => setOpen(value => !value)}
      onFocus={() => { if (!isMobile) setOpen(true); }}
      onBlur={() => { if (!isMobile) setOpen(false); }}
      style={{ width: isMobile ? 16 : 20, height: isMobile ? 16 : 20, borderRadius: "50%", display: "inline-flex", alignItems: "center", justifyContent: "center", color: inverted ? "#fff" : C.primary, background: inverted ? "rgba(255,255,255,.14)" : C.primaryLight, border: inverted ? "1px solid rgba(255,255,255,.2)" : `1px solid ${C.primary}22`, flexShrink: 0 }}
    >
      <Info size={isMobile ? 9 : 12} aria-hidden="true" />
    </button>
    {open && !isMobile && <span id={tooltipId} role="tooltip" style={{ position: "absolute", zIndex: 20, top: 26, left: 0, width: 280, padding: "11px 12px", borderRadius: 11, background: C.ink, color: "#fff", fontSize: 11, fontWeight: 500, lineHeight: 1.5, letterSpacing: 0, boxShadow: "0 12px 30px rgba(15,22,38,.24)", textTransform: "none" }}>{explanation}</span>}
    {open && isMobile && <>
      <span onClick={() => setOpen(false)} aria-hidden="true" style={{ position: "fixed", inset: 0, zIndex: 70, background: "rgba(15,22,38,.38)" }} />
      <span id={tooltipId} role="dialog" aria-modal="true" aria-label={`About ${label}`} style={{ position: "fixed", zIndex: 71, left: 12, right: 12, bottom: 12, padding: 18, borderRadius: 18, background: C.card, color: C.ink, boxShadow: "0 18px 50px rgba(15,22,38,.28)", textTransform: "none", letterSpacing: 0 }}>
        <span style={{ display: "flex", alignItems: "center", justifyContent: "space-between", gap: 12 }}>
          <strong style={{ fontSize: 14 }}>{label}</strong>
          <button type="button" aria-label="Close explanation" onClick={() => setOpen(false)} style={{ width: 30, height: 30, borderRadius: 9, background: "#F4F6FB", display: "inline-flex", alignItems: "center", justifyContent: "center" }}><X size={15} color={C.gray} /></button>
        </span>
        <span style={{ display: "block", fontSize: 12, color: C.gray, lineHeight: 1.6, marginTop: 9 }}>{explanation}</span>
      </span>
    </>}
  </span>;
}

function UnifiedPayments({ goTo, bp, activity, detailScreen }: { goTo: (s: Screen) => void; bp: BP; activity?: PaymentActivity; detailScreen?: Screen }) {
  const resolvedActivity: PaymentActivity = activity ?? (detailScreen === "emp-wallet" ? "client" : "market");
  const activityStats = paymentStats[resolvedActivity] ?? paymentStats.market;
  const filteredPayments = sharedPayments.filter(transaction => transaction.activity === resolvedActivity);
  const [financialAction, setFinancialAction] = useState<"withdraw" | "statement" | null>(null);
  return <div style={{ flex: 1, overflowY: "auto", padding: bp.isMobile ? "20px 16px 80px" : 28 }}>
    <div style={{ maxWidth: 1080, margin: "0 auto" }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-end", gap: 12, flexWrap: "wrap" }}>
        <div><Pill label="UNIFIED HIVORR WALLET" color={C.primary} bg={C.primaryLight} /><h1 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontSize: 26, fontWeight: 800, color: C.ink, marginTop: 9 }}>Payments</h1><p style={{ fontSize: 13, color: C.gray, marginTop: 4 }}>{paymentLabels[resolvedActivity]} records from your shared Hivorr account.</p></div>
        {detailScreen && <Btn size="sm" variant="secondary" onClick={() => goTo(detailScreen)}>Client payment details</Btn>}
      </div>
      <div style={{ background: "linear-gradient(135deg,#1A2AD4,#2D3FE7 58%,#5363F2)", borderRadius: 22, padding: bp.isMobile ? 20 : 26, marginTop: 20, color: "#fff", boxShadow: "0 16px 38px rgba(45,63,231,.2)" }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", gap: 16, flexWrap: "wrap" }}>
          <div><p style={{ fontSize: 11, fontWeight: 700, color: "rgba(255,255,255,.68)", letterSpacing: .6 }}><WalletInfo label="TOTAL HIVORR WALLET BALANCE" explanation={walletExplanations.total} isMobile={bp.isMobile} inverted /></p><p style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontSize: bp.isMobile ? 32 : 38, fontWeight: 800, marginTop: 6 }}>{SHARED_WALLET.total}</p><p style={{ fontSize: 10, color: "rgba(255,255,255,.58)", marginTop: 5 }}>Available balance plus pending funds across Hivorr</p></div>
          <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}><button style={{ background: "#fff", color: C.primary, padding: "10px 13px", borderRadius: 10, fontSize: 11, fontWeight: 800, display: "flex", gap: 5, alignItems: "center" }}><Plus size={13} /> Fund Wallet</button><button onClick={() => setFinancialAction("withdraw")} style={{ background: "rgba(255,255,255,.14)", color: "#fff", border: "1px solid rgba(255,255,255,.2)", padding: "10px 13px", borderRadius: 10, fontSize: 11, fontWeight: 800, display: "flex", gap: 5, alignItems: "center" }}><ArrowUpFromLine size={13} /> Withdraw</button><button onClick={() => setFinancialAction("statement")} style={{ background: "rgba(255,255,255,.14)", color: "#fff", border: "1px solid rgba(255,255,255,.2)", padding: "10px 13px", borderRadius: 10, fontSize: 11, fontWeight: 800, display: "flex", gap: 5, alignItems: "center" }}><Eye size={13} /> Statement</button></div>
        </div>
        <div style={{ display: "grid", gridTemplateColumns: "repeat(3,minmax(0,1fr))", gap: bp.isMobile ? 6 : 10, marginTop: 22 }}>{[["Available Balance",SHARED_WALLET.available,walletExplanations.available],["Pending Across Hivorr",SHARED_WALLET.pending,walletExplanations.pending],["Withdrawable Balance",SHARED_WALLET.withdrawable,walletExplanations.withdrawable]].map(([label,value,explanation])=><div key={label} style={{ background: "rgba(255,255,255,.1)", borderRadius: 12, padding: bp.isMobile ? "8px 6px" : 12, minWidth: 0 }}><p style={{ fontSize: bp.isMobile ? 8 : 10, color: "rgba(255,255,255,.62)", minHeight: bp.isMobile ? 32 : "auto" }}><WalletInfo label={label} explanation={explanation} isMobile={bp.isMobile} inverted /></p><p title={value} style={{ fontSize: bp.isMobile ? 11 : 17, fontWeight: 800, marginTop: 4, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{value}</p></div>)}</div>
      </div>
      <div style={{ display: "grid", gridTemplateColumns: bp.isMobile ? "repeat(2,1fr)" : "repeat(3,1fr)", gap: 12, marginTop: 18 }}>{activityStats.map(([label,value],i)=><StatCard key={label} label={label} value={value} icon={<Wallet size={18} color={[C.primary,C.orange,C.purple,C.green][i]} />} color={[C.primary,C.orange,C.purple,C.green][i]} bg={[C.primaryLight,C.orangeLight,C.purpleLight,C.greenLight][i]} />)}</div>
      <div style={{ display: "grid", gridTemplateColumns: bp.isDesktop ? "1.4fr .6fr" : "1fr", gap: 18, marginTop: 18 }}>
        <Card><div style={{ display: "flex", justifyContent: "space-between", alignItems: "center",gap:10,flexWrap:"wrap" }}><div><h2 style={{ fontSize: 15, fontWeight: 800, color: C.ink }}>{paymentLabels[resolvedActivity]} Payment History</h2><p style={{ fontSize: 10, color: C.muted, marginTop: 3 }}>Only transactions associated with this activity</p></div><Btn size="sm" variant="ghost" icon={<Filter size={12} />}>Filter</Btn></div>{filteredPayments.map((transaction,i)=><div key={transaction.ref} style={{ display: "flex", alignItems: "center", gap: 11, padding: "13px 0", borderTop: i ? `1px solid ${C.border}` : "none",flexWrap:bp.isMobile?"wrap":"nowrap" }}><div style={{ width: 38, height: 38, borderRadius: 11, background: transaction.amount.startsWith("+") ? C.greenLight : C.primaryLight, display: "flex", alignItems: "center", justifyContent: "center",flexShrink:0 }}>{transaction.amount.startsWith("+") ? <ArrowDownToLine size={16} color={C.green} /> : <ArrowUpFromLine size={16} color={C.primary} />}</div><div style={{ flex: 1, minWidth: bp.isMobile?180:0 }}><p style={{ fontSize: 12, fontWeight: 700, color: C.ink, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{transaction.desc}</p><p style={{ fontSize: 10, color: C.muted, marginTop: 3 }}>{transaction.date} · {transaction.ref}</p></div><strong style={{ fontSize: 12, color: transaction.amount.startsWith("+") ? C.green : C.ink }}>{transaction.amount}</strong><Pill label={transaction.status} color={transaction.color} bg={transaction.bg} /></div>)}</Card>
        <div style={{ display: "flex", flexDirection: "column", gap: 14 }}><Card><h2 style={{ fontSize: 15, fontWeight: 800, color: C.ink }}>Saved payment methods</h2><div style={{ display: "flex", gap: 10, alignItems: "center", marginTop: 13 }}><div style={{ width: 42, height: 30, borderRadius: 7, background: C.ink, color: "#fff", display: "flex", alignItems: "center", justifyContent: "center", fontSize: 9, fontWeight: 800 }}>VISA</div><div><p style={{ fontSize: 12, fontWeight: 700, color: C.ink }}>•••• 4182</p><p style={{ fontSize: 10, color: C.muted }}>Default · expires 08/28</p></div></div><button style={{ color: C.primary, fontSize: 11, fontWeight: 700, marginTop: 13 }}>Manage methods</button></Card><div style={{ background: C.orangeLight, borderRadius: 15, padding: 15, display: "flex", gap: 9 }}><AlertCircle size={17} color={C.orange} /><p style={{ fontSize: 10, color: C.gray, lineHeight: 1.5 }}>Illustrative records only. Funding and withdrawal buttons do not transfer real money.</p></div></div>
      </div>
    </div>
    {financialAction && <FinancialActionDialog mode={financialAction} context={`${paymentLabels[resolvedActivity]} payments`} transactions={filteredPayments} onClose={() => setFinancialAction(null)} />}
  </div>;
}

type EarningActivity = "seller" | "professional" | "logistics";
const earningLabels: Record<EarningActivity, string> = { seller: "Product Sales", professional: "Professional Services", logistics: "Logistics" };
const earningAnalysisLabels: Record<EarningActivity, string> = {
  seller: "Sales Analysis",
  professional: "Earnings Analysis",
  logistics: "Analysis",
};
const earningPayouts = [
  { activity: "seller", reference: "WD-1184", amount: "₦84,000", date: "Jul 12", status: "Successful" },
  { activity: "professional", reference: "WD-1181", amount: "₦220,000", date: "Jul 12", status: "Successful" },
  { activity: "logistics", reference: "PO-1178", amount: "₦16,000", date: "Jul 12", status: "Successful" },
  { activity: "logistics", reference: "PO-1192", amount: "₦64,200", date: "Estimated Friday", status: "Pending" },
] satisfies Array<{ activity: EarningActivity; reference: string; amount: string; date: string; status: "Successful" | "Pending" | "Failed" }>;

const earningWalletExplanations = {
  total: "This is the total money recorded in your Hivorr wallet across your activities, including money that is available and money temporarily held.",
  available: "This is the money you can currently use, subject to Hivorr's applicable financial rules.",
  pending: "This is money that is temporarily unavailable while an order, service, delivery, or other applicable transaction awaits the required completion or settlement.",
  withdrawable: "This is the amount you can currently withdraw from your Hivorr wallet, subject to withdrawal requirements.",
};

function UnifiedEarnings({ goTo, bp, activity, detailScreen, detailLabel }: { goTo: (s: Screen) => void; bp: BP; activity?: EarningActivity; detailScreen: Screen; detailLabel: string }) {
  const resolvedActivity: EarningActivity = activity ?? "professional";
  const filteredEarnings = sharedEarnings.filter(transaction => transaction.activity === resolvedActivity);
  const filteredPayouts = earningPayouts.filter(payout => payout.activity === resolvedActivity);
  const [financialAction, setFinancialAction] = useState<"withdraw" | "statement" | null>(null);
  return <div style={{ flex: 1, overflowY: "auto", padding: bp.isMobile ? "20px 16px 80px" : 28 }}>
    <div style={{ maxWidth: 1080, margin: "0 auto" }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-end", gap: 12, flexWrap: "wrap" }}><div><Pill label="SHARED HIVORR WALLET" color={C.green} bg={C.greenLight} /><h1 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontSize: 26, fontWeight: 800, color: C.ink, marginTop: 9 }}>Earnings</h1><p style={{ fontSize: 13, color: C.gray, marginTop: 4 }}>Your shared wallet position, with {earningLabels[resolvedActivity].toLowerCase()} records kept separate.</p></div><Btn size="sm" variant="secondary" onClick={() => goTo(detailScreen)}>{detailLabel || earningAnalysisLabels[resolvedActivity]}</Btn></div>
      <div style={{ background: "linear-gradient(135deg,#116530,#16A34A 58%,#22C55E)", borderRadius: 22, padding: bp.isMobile ? 20 : 26, marginTop: 20, color: "#fff", boxShadow: "0 16px 38px rgba(22,163,74,.18)" }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", gap: 16, flexWrap: "wrap" }}>
          <div><p style={{ fontSize: 11, fontWeight: 700, color: "rgba(255,255,255,.68)", letterSpacing: .6 }}><WalletInfo label="TOTAL HIVORR WALLET BALANCE" explanation={earningWalletExplanations.total} isMobile={bp.isMobile} inverted /></p><p style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontSize: bp.isMobile ? 32 : 38, fontWeight: 800, marginTop: 6 }}>{SHARED_WALLET.total}</p><p style={{ fontSize: 10, color: "rgba(255,255,255,.58)", marginTop: 5 }}>Available balance plus pending funds across Hivorr</p></div>
          <div style={{ display: "flex", gap: 8 }}><button onClick={() => setFinancialAction("withdraw")} style={{ background: "#fff", color: C.green, padding: "10px 13px", borderRadius: 10, fontSize: 11, fontWeight: 800, display: "flex", gap: 5, alignItems: "center" }}><ArrowUpFromLine size={13} /> Withdraw</button><button onClick={() => setFinancialAction("statement")} style={{ background: "rgba(255,255,255,.14)", color: "#fff", border: "1px solid rgba(255,255,255,.2)", padding: "10px 13px", borderRadius: 10, fontSize: 11, fontWeight: 800, display: "flex", gap: 5, alignItems: "center" }}><Eye size={13} /> Statement</button></div>
        </div>
        <div style={{ display: "grid", gridTemplateColumns: "repeat(3,minmax(0,1fr))", gap: bp.isMobile ? 6 : 9, marginTop: 22 }}>
          {[["Available Balance",SHARED_WALLET.available,earningWalletExplanations.available],["Pending Across Hivorr",SHARED_WALLET.pending,earningWalletExplanations.pending],["Withdrawable Balance",SHARED_WALLET.withdrawable,earningWalletExplanations.withdrawable]].map(([label,value,explanation])=><div key={label} style={{ background: "rgba(255,255,255,.1)", borderRadius: 12, padding: bp.isMobile ? "8px 6px" : 11, minWidth: 0 }}><p style={{ fontSize: bp.isMobile ? 8 : 9, color: "rgba(255,255,255,.62)", minHeight: bp.isMobile ? 32 : "auto" }}><WalletInfo label={label} explanation={explanation} isMobile={bp.isMobile} inverted /></p><p title={value} style={{ fontSize: bp.isMobile ? 11 : 16, fontWeight: 800, marginTop: 4, overflow: "hidden", textOverflow: "ellipsis", whiteSpace: "nowrap" }}>{value}</p></div>)}
        </div>
      </div>
      <div style={{ display: "grid", gridTemplateColumns: bp.isDesktop ? "1.25fr .75fr" : "1fr", gap: 18, marginTop: 18 }}>
        <Card><div style={{ display: "flex", justifyContent: "space-between",gap:10,flexWrap:"wrap" }}><div><h2 style={{ fontSize: 15, fontWeight: 800, color: C.ink }}>{earningLabels[resolvedActivity]} Earnings History</h2><p style={{ fontSize: 10, color: C.muted, marginTop: 3 }}>Only financially recorded transactions for this activity</p></div><Btn size="sm" variant="ghost" icon={<Filter size={12} />}>Filter</Btn></div>{filteredEarnings.map((transaction,i)=><div key={`${transaction.activity}-${transaction.desc}`} style={{ display: "flex", alignItems: "center", gap: 11, padding: "13px 0", borderTop: i ? `1px solid ${C.border}` : "none",flexWrap:bp.isMobile?"wrap":"nowrap" }}><div style={{ width: 38, height: 38, borderRadius: 11, background: transaction.bg, display: "flex", alignItems: "center", justifyContent: "center",flexShrink:0 }}><DollarSign size={16} color={transaction.color} /></div><div style={{ flex: 1,minWidth:bp.isMobile?180:0 }}><p style={{ fontSize: 12, fontWeight: 700, color: C.ink }}>{transaction.desc}</p><p style={{ fontSize: 10, color: C.muted, marginTop: 3 }}>{transaction.activityLabel} · {transaction.date}</p></div><strong style={{ fontSize: 12, color: transaction.status === "Available" ? C.green : C.orange }}>{transaction.amount}</strong><Pill label={transaction.status} color={transaction.color} bg={transaction.bg} /></div>)}</Card>
        <Card><h2 style={{ fontSize: 15, fontWeight: 800, color: C.ink }}>Withdrawals & payouts</h2><p style={{ fontSize: 10, color: C.muted, marginTop: 3 }}>Settlement history remains available from Earnings</p>{filteredPayouts.map((payout,i)=><div key={payout.reference} style={{ padding: "13px 0", borderTop: i ? `1px solid ${C.border}` : "none", display: "flex", alignItems: "center", gap: 10 }}><div style={{ flex: 1 }}><p style={{ fontSize: 12, fontWeight: 700, color: C.ink }}>{payout.amount}</p><p style={{ fontSize: 10, color: C.muted, marginTop: 3 }}>{payout.reference} · {payout.date}</p></div><Pill label={payout.status.toUpperCase()} color={payout.status === "Successful" ? C.green : payout.status === "Pending" ? C.orange : C.red} bg={payout.status === "Successful" ? C.greenLight : payout.status === "Pending" ? C.orangeLight : C.redLight} /></div>)}</Card>
      </div>
      <p style={{ fontSize: 10, color: C.muted, marginTop: 10 }}>Wallet figures are derived once from available, held, pending-settlement, and withdrawal-eligible records. Activity revenue and performance remain in Analysis.</p>
    </div>
    {financialAction && <FinancialActionDialog mode={financialAction} context={`${earningLabels[resolvedActivity]} earnings`} transactions={filteredEarnings} onClose={() => setFinancialAction(null)} />}
  </div>;
}

function UnifiedProfile({ goTo, bp, detailScreen, detailLabel }: { goTo:(s:Screen)=>void; bp:BP; detailScreen?:Screen; detailLabel?:string }) {
  return <div style={{ flex:1,overflowY:"auto",padding:bp.isMobile?"20px 16px 80px":28 }}><div style={{ maxWidth:920,margin:"0 auto" }}><div><Pill label="ONE HIVORR ACCOUNT" color={C.primary} bg={C.primaryLight}/><h1 style={{ fontFamily:"'Plus Jakarta Sans',sans-serif",fontSize:26,fontWeight:800,color:C.ink,marginTop:9 }}>Profile & account</h1><p style={{ fontSize:13,color:C.gray,marginTop:4 }}>Your personal identity remains shared across every Hivorr activity.</p></div><div style={{ display:"grid",gridTemplateColumns:bp.isDesktop?".7fr 1.3fr":"1fr",gap:18,marginTop:20 }}><Card><div style={{ textAlign:"center" }}><Av initials="AD" color={C.primary} size={72}/><h2 style={{ fontSize:17,fontWeight:800,color:C.ink,marginTop:10 }}>Amara Diallo</h2><p style={{ fontSize:12,color:C.gray,marginTop:3 }}>amara@email.com</p><div style={{ marginTop:10 }}><Pill label="IDENTITY VERIFIED" color={C.green} bg={C.greenLight}/></div></div></Card><Card><h2 style={{ fontSize:15,fontWeight:800,color:C.ink }}>Personal information</h2><div style={{ display:"grid",gridTemplateColumns:bp.isMobile?"1fr":"1fr 1fr",gap:12,marginTop:14 }}><Input label="Full name" defaultValue="Amara Diallo"/><Input label="Phone" defaultValue="+234 800 000 0000"/><Input label="Email" defaultValue="amara@email.com"/><Input label="Country" defaultValue="Nigeria"/></div><div style={{ marginTop:14 }}><Btn size="sm">Save changes</Btn></div></Card></div><Card style={{ marginTop:18 }}><h2 style={{ fontSize:15,fontWeight:800,color:C.ink }}>Activity identities</h2><div style={{ display:"grid",gridTemplateColumns:bp.isDesktop?"repeat(3,1fr)":"1fr",gap:10,marginTop:13 }}>{[{l:"Zuri Craft House",s:"Seller store",i:Store,c:C.purple,b:C.purpleLight},{l:"Full-Stack Developer",s:"Professional profile",i:Award,c:C.green,b:C.greenLight},{l:"Lagos · Car",s:"Logistics eligibility",i:Truck,c:C.orange,b:C.orangeLight}].map(x=><div key={x.s} style={{ padding:13,borderRadius:13,background:"#F8F9FC",display:"flex",gap:9,alignItems:"center",minWidth:0 }}><div style={{ width:36,height:36,borderRadius:10,background:x.b,display:"flex",alignItems:"center",justifyContent:"center",flexShrink:0 }}><x.i size={16} color={x.c}/></div><div style={{ minWidth:0 }}><p style={{ fontSize:11,fontWeight:700,color:C.ink }}>{x.l}</p><p style={{ fontSize:10,color:C.muted }}>{x.s}</p></div></div>)}</div>{detailScreen&&<div style={{ marginTop:14 }}><Btn size="sm" variant="secondary" onClick={()=>goTo(detailScreen)}>{detailLabel}</Btn></div>}</Card><div style={{ background:C.orangeLight,borderRadius:14,padding:14,display:"flex",gap:9,marginTop:14 }}><Shield size={17} color={C.orange}/><p style={{ fontSize:10,color:C.gray,lineHeight:1.5 }}>Profile edits do not bypass store, professional, trade, or logistics verification requirements.</p></div></div></div>;
}

function MarketHome({ goTo, bp, onBrowseCategory }: { goTo: (s: Screen) => void; bp: BP; onBrowseCategory: (category: string) => void }) {
  return (
    <main style={{ padding: bp.isMobile ? "18px 16px 90px" : "28px 32px 48px", maxWidth: 1240, margin: "0 auto" }}>
      <section style={{ background: "linear-gradient(125deg,#1D2CC9,#3D50F1)", borderRadius: 24, padding: bp.isMobile ? "26px 20px" : "38px 42px", color: "#fff", display: "grid", gridTemplateColumns: bp.isDesktop ? "1.3fr 0.7fr" : "1fr", gap: 24, alignItems: "center", overflow: "hidden", position: "relative" }}>
        <div style={{ position: "relative", zIndex: 1 }}>
          <p style={{ fontSize: 11, fontWeight: 800, letterSpacing: 1.3, color: "rgba(255,255,255,.72)" }}>SHOP LOCAL. DISCOVER MORE.</p>
          <h1 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: bp.isMobile ? 28 : 38, lineHeight: 1.15, maxWidth: 560, marginTop: 8 }}>Everything you need, closer than you think.</h1>
          <p style={{ fontSize: 14, lineHeight: 1.6, color: "rgba(255,255,255,.75)", maxWidth: 520, marginTop: 10 }}>Discover trusted sellers, unique products, and convenient local delivery across your city.</p>
          <div style={{ marginTop: 20, background: "#fff", borderRadius: 14, padding: "5px 6px 5px 14px", display: "flex", alignItems: "center", gap: 9, maxWidth: 570 }}>
            <Search size={18} color={C.muted} />
            <input placeholder="Search products, stores or categories" style={{ flex: 1, minWidth: 0, background: "transparent", border: 0, outline: 0, color: C.ink, fontSize: 13 }} />
            <button style={{ background: C.primary, color: "#fff", borderRadius: 10, padding: "10px 14px", fontSize: 12, fontWeight: 700 }}>Search</button>
          </div>
        </div>
        {bp.isDesktop && <div style={{ position: "relative", height: 190 }}><img src={productImages.fashion} alt="Colorful local market fabrics" style={{ width: "100%", height: "100%", objectFit: "cover", borderRadius: 22, transform: "rotate(3deg)", border: "5px solid rgba(255,255,255,.18)" }} /></div>}
      </section>

      <section style={{ marginTop: 28 }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "end", marginBottom: 14 }}>
          <div><h2 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 19, color: C.ink }}>Browse categories</h2><p style={{ fontSize: 12, color: C.muted, marginTop: 3 }}>Find the right aisle quickly</p></div>
          <button onClick={() => onBrowseCategory("All products")} style={{ fontSize: 12, fontWeight: 700, color: C.primary }}>View all</button>
        </div>
        <div style={{ display: "grid", gridTemplateColumns: bp.isMobile ? "repeat(4, minmax(72px,1fr))" : "repeat(8,1fr)", gap: 10, overflowX: bp.isMobile ? "auto" : "visible" }}>
          {marketCategories.map(category => {
            const Icon = category.icon;
            return <button key={category.label} onClick={() => onBrowseCategory(category.label === "More" ? "All products" : category.label)} style={{ background: C.card, border: `1px solid ${C.border}`, borderRadius: 15, padding: "14px 8px", minWidth: 78, display: "flex", alignItems: "center", flexDirection: "column", gap: 8 }}><div style={{ width: 38, height: 38, borderRadius: 12, background: category.bg, display: "flex", alignItems: "center", justifyContent: "center" }}><Icon size={18} color={category.color} /></div><span style={{ fontSize: 10, fontWeight: 700, lineHeight: 1.25, color: C.ink, textAlign: "center" }}>{category.label}</span></button>;
          })}
        </div>
      </section>

      <section style={{ marginTop: 30 }}>
        <div style={{ display: "flex", alignItems: "center", justifyContent: "space-between", marginBottom: 14 }}>
          <div><h2 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 19, color: C.ink }}>Featured near you</h2><p style={{ fontSize: 12, color: C.muted, marginTop: 3, display: "flex", alignItems: "center", gap: 4 }}><MapPin size={11} /> Lagos · within 25 km</p></div>
          <button style={{ display: "flex", alignItems: "center", gap: 5, background: C.card, border: `1px solid ${C.border}`, borderRadius: 10, padding: "8px 10px", fontSize: 11, fontWeight: 700, color: C.gray }}><SlidersHorizontal size={13} /> Filters</button>
        </div>
        <div style={{ display: "grid", gridTemplateColumns: bp.isMobile ? "repeat(2, minmax(0,1fr))" : "repeat(4, minmax(0,1fr))", gap: bp.isMobile ? 10 : 16 }}>
          {products.map(product => <ProductCard key={product.id} product={product} onOpen={() => goTo("product-detail")} />)}
        </div>
      </section>

      <section style={{ marginTop: 30, display: "grid", gridTemplateColumns: bp.isDesktop ? "1fr 1fr" : "1fr", gap: 16 }}>
        <div style={{ background: C.card, borderRadius: 18, padding: 20, border: `1px solid ${C.border}`, display: "flex", gap: 15, alignItems: "center" }}>
          <Av initials="ZC" color={C.purple} size={50} /><div style={{ flex: 1 }}><Pill label="FEATURED STORE" color={C.purple} bg={C.purpleLight} /><p style={{ fontSize: 15, fontWeight: 800, color: C.ink, marginTop: 7 }}>Zuri Craft House</p><p style={{ fontSize: 12, color: C.gray, marginTop: 3 }}>Handmade pieces from 12 local artisans</p></div><ChevronRight size={19} color={C.muted} />
        </div>
        <div style={{ background: C.greenLight, borderRadius: 18, padding: 20, display: "flex", gap: 15, alignItems: "center" }}>
          <div style={{ width: 50, height: 50, borderRadius: 15, background: "#fff", display: "flex", alignItems: "center", justifyContent: "center" }}><Store size={23} color={C.green} /></div><div style={{ flex: 1 }}><p style={{ fontSize: 15, fontWeight: 800, color: C.ink }}>Have something to sell?</p><p style={{ fontSize: 12, color: C.gray, marginTop: 3 }}>Open your Hivorr store in a few guided steps.</p></div><Btn size="sm" onClick={() => goTo("seller-home")}>Start selling</Btn>
        </div>
      </section>
    </main>
  );
}

function MarketBrowse({ goTo, bp, initialCategory }: { goTo: (s: Screen) => void; bp: BP; initialCategory?: string }) {
  const [sort, setSort] = useState("Most relevant");
  const [search, setSearch] = useState("");
  const [appliedSearch, setAppliedSearch] = useState("");
  const [filterOpen, setFilterOpen] = useState(false);
  const initialFilters = () => initialCategory && initialCategory !== "All products" ? { ...emptyMarketFilters(), categories: [initialCategory] } : emptyMarketFilters();
  const [draftFilters, setDraftFilters] = useState<MarketFilterState>(initialFilters);
  const [appliedFilters, setAppliedFilters] = useState<MarketFilterState>(initialFilters);
  const openFilters = () => {
    setDraftFilters({ ...appliedFilters, categories: [...appliedFilters.categories], availability: [...appliedFilters.availability], sellers: [...appliedFilters.sellers], conditions: [...appliedFilters.conditions] });
    setFilterOpen(true);
  };
  const resetFilters = () => {
    const empty = emptyMarketFilters();
    setDraftFilters(empty);
    setAppliedFilters(empty);
  };
  const applyFilters = () => {
    setAppliedFilters({ ...draftFilters, categories: [...draftFilters.categories], availability: [...draftFilters.availability], sellers: [...draftFilters.sellers], conditions: [...draftFilters.conditions] });
    setFilterOpen(false);
  };
  const activeFilterCount = appliedFilters.categories.length + appliedFilters.availability.length + appliedFilters.sellers.length + appliedFilters.conditions.length + (appliedFilters.price ? 1 : 0);
  const visibleProducts = [...products, ...products.slice(0, 2)]
    .filter(product => !appliedSearch || `${product.name} ${product.seller} ${product.category}`.toLowerCase().includes(appliedSearch.toLowerCase()))
    .filter(product => !appliedFilters.categories.length || appliedFilters.categories.includes(product.category))
    .filter(product => !appliedFilters.sellers.length || appliedFilters.sellers.includes(product.seller))
    .filter(product => !appliedFilters.availability.length || appliedFilters.availability.some(selected => selected === "In stock" ? product.stock > 0 : product.stock > 0 && product.stock <= 7))
    .filter(product => !appliedFilters.conditions.length || appliedFilters.conditions.includes("New") || appliedFilters.conditions.includes("Verified listing"))
    .filter(product => !appliedFilters.price || (appliedFilters.price === "₦5,000 – ₦20,000" ? product.price >= 5000 && product.price < 20000 : appliedFilters.price === "₦20,000 – ₦40,000" ? product.price >= 20000 && product.price < 40000 : product.price >= 40000 && product.price <= 75000))
    .sort((a, b) => sort === "Price: Low to high" ? a.price - b.price : 0);
  return <main style={{ maxWidth: 1220, margin: "0 auto", padding: bp.isMobile ? "20px 16px 90px" : "30px 32px" }}>
    <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-end", gap: 14, flexWrap: "wrap" }}>
      <div style={{ minWidth: 0 }}><Pill label="ILLUSTRATIVE PRODUCTS" color={C.primary} bg={C.primaryLight} /><h1 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontSize: 27, fontWeight: 800, color: C.ink, marginTop: 10 }}>Browse Local Market</h1><p style={{ fontSize: 13, color: C.gray, marginTop: 4 }}>Search and compare products from verified local sellers.</p></div>
      <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
        <button style={{ background: C.card, border: `1px solid ${C.border}`, borderRadius: 11, padding: "9px 12px", display: "flex", gap: 6, alignItems: "center", fontSize: 12, fontWeight: 700, color: C.gray }}><MapPin size={13} /> Lagos · 25 km</button>
        <button onClick={() => setSort(sort === "Most relevant" ? "Price: Low to high" : "Most relevant")} style={{ background: C.card, border: `1px solid ${C.border}`, borderRadius: 11, padding: "9px 12px", display: "flex", alignItems: "center", gap: 5, fontSize: 12, fontWeight: 700, color: C.gray }}>{sort} <ChevronDown size={12} /></button>
        <div style={{ position: "relative" }}><button aria-expanded={filterOpen} aria-haspopup="dialog" onClick={openFilters} style={{ background: activeFilterCount ? C.primaryLight : C.card, border: `1px solid ${activeFilterCount ? C.primary : C.border}`, borderRadius: 11, padding: "9px 12px", display: "flex", alignItems: "center", gap: 6, fontSize: 12, fontWeight: 800, color: activeFilterCount ? C.primary : C.gray }}><SlidersHorizontal size={14} /> Filter{activeFilterCount > 0 && <span style={{ minWidth: 18, height: 18, borderRadius: 9, padding: "0 5px", background: C.primary, color: "#fff", display: "inline-flex", alignItems: "center", justifyContent: "center", fontSize: 9 }}>{activeFilterCount}</span>}</button>{filterOpen && <MarketFilterPanel bp={bp} filters={draftFilters} onChange={setDraftFilters} onApply={applyFilters} onReset={resetFilters} onClose={() => setFilterOpen(false)} />}</div>
      </div>
    </div>
    <div style={{ background: C.card, borderRadius: 16, border: `1px solid ${C.border}`, padding: bp.isMobile ? 10 : 12, marginTop: 20, display: "flex", alignItems: "center", gap: 9 }}><Search size={17} color={C.muted} /><input value={search} onChange={event => setSearch(event.target.value)} onKeyDown={event => event.key === "Enter" && setAppliedSearch(search.trim())} placeholder="Search products, stores, categories, or attributes" style={{ flex: 1, minWidth: 0, border: 0, outline: 0, background: "transparent", fontSize: 13 }} /><Btn size="sm" onClick={() => setAppliedSearch(search.trim())}>Search</Btn></div>
    <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", gap: 10, marginTop: 18, marginBottom: 12 }}><p style={{ fontSize: 12, color: C.gray }}><strong style={{ color: C.ink }}>{visibleProducts.length}</strong> products</p>{activeFilterCount > 0 && <button onClick={resetFilters} style={{ color: C.primary, fontSize: 11, fontWeight: 800 }}>Clear filters</button>}</div>
    {visibleProducts.length > 0 ? <div style={{ display: "grid", gridTemplateColumns: bp.isMobile ? "repeat(2,minmax(0,1fr))" : "repeat(3,minmax(0,1fr))", gap: bp.isMobile ? 10 : 14 }}>{visibleProducts.map((product, i) => <ProductCard key={`${product.id}-${i}`} product={product} compact={bp.isMobile} onOpen={() => goTo("product-detail")} />)}</div> : <Card><div style={{ textAlign: "center", padding: bp.isMobile ? 12 : 20 }}><Search size={24} color={C.muted} /><p style={{ fontSize: 14, fontWeight: 800, color: C.ink, marginTop: 9 }}>No products match these filters</p><p style={{ fontSize: 12, color: C.gray, marginTop: 4 }}>Reset the filters or try a broader search.</p><div style={{ display: "flex", justifyContent: "center", marginTop: 12 }}><Btn size="sm" variant="secondary" onClick={resetFilters}>Reset filters</Btn></div></div></Card>}
  </main>;
}

function MarketSaved({ goTo, bp }: { goTo: (s: Screen) => void; bp: BP }) {
  return <main style={{ maxWidth: 1080, margin: "0 auto", padding: bp.isMobile ? "22px 16px 90px" : "32px" }}><div><h1 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontSize: 27, fontWeight: 800, color: C.ink }}>Saved products</h1><p style={{ fontSize: 13, color: C.gray, marginTop: 4 }}>Products you want to revisit later.</p></div><div style={{ display: "grid", gridTemplateColumns: bp.isMobile ? "repeat(2,1fr)" : "repeat(3,1fr)", gap: 14, marginTop: 20 }}>{products.slice(0, 3).map(product => <ProductCard key={product.id} product={product} onOpen={() => goTo("product-detail")} />)}</div></main>;
}

function ProductDetail({ goTo, bp, onAdd }: { goTo: (s: Screen) => void; bp: BP; onAdd: () => void }) {
  const product = products[0];
  const [variation, setVariation] = useState("Natural");
  return (
    <main style={{ maxWidth: 1120, margin: "0 auto", padding: bp.isMobile ? "16px 16px 90px" : "28px 32px 50px" }}>
      <button onClick={() => goTo("market-home")} style={{ display: "flex", alignItems: "center", gap: 6, color: C.gray, fontSize: 13, fontWeight: 600, marginBottom: 18 }}><ArrowLeft size={16} /> Back to market</button>
      <div style={{ display: "grid", gridTemplateColumns: bp.isDesktop ? "1fr 1fr" : "1fr", gap: 28 }}>
        <div>
          <div style={{ height: bp.isMobile ? 340 : 510, background: "#E9ECF5", borderRadius: 22, overflow: "hidden" }}><img src={product.image} alt={product.name} style={{ width: "100%", height: "100%", objectFit: "cover" }} /></div>
          <div style={{ display: "flex", gap: 9, marginTop: 10 }}>{[product.image, productImages.fashion, productImages.groceries].map((image, i) => <button key={i} style={{ width: 66, height: 66, borderRadius: 12, overflow: "hidden", border: `2px solid ${i === 0 ? C.primary : "transparent"}` }}><img src={image} alt="" style={{ width: "100%", height: "100%", objectFit: "cover" }} /></button>)}</div>
        </div>
        <div>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start" }}><Pill label="HANDMADE · IN STOCK" color={C.green} bg={C.greenLight} /><button style={{ width: 38, height: 38, borderRadius: 11, background: C.card, display: "flex", alignItems: "center", justifyContent: "center" }}><Heart size={18} color={C.gray} /></button></div>
          <h1 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: bp.isMobile ? 27 : 34, lineHeight: 1.2, color: C.ink, marginTop: 14 }}>{product.name}</h1>
          <div style={{ display: "flex", alignItems: "center", gap: 12, marginTop: 8 }}><Stars rating={product.rating} reviews={product.reviews} /><span style={{ fontSize: 12, color: C.muted }}>24 sold this month</span></div>
          <p style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontSize: 28, fontWeight: 800, color: C.primary, marginTop: 22 }}>₦{product.price.toLocaleString()}</p>
          <p style={{ fontSize: 14, color: C.gray, lineHeight: 1.75, marginTop: 15 }}>A durable everyday tote handwoven by local artisans using responsibly sourced natural fibres. Spacious, lightweight, and uniquely finished.</p>
          <div style={{ borderTop: `1px solid ${C.border}`, marginTop: 20, paddingTop: 18 }}>
            <p style={{ fontSize: 13, fontWeight: 700, color: C.ink, marginBottom: 9 }}>Colour</p>
            <div style={{ display: "flex", gap: 8 }}>{["Natural", "Indigo", "Terracotta"].map(item => <button key={item} onClick={() => setVariation(item)} style={{ padding: "9px 12px", borderRadius: 10, background: variation === item ? C.primaryLight : C.card, border: `1.5px solid ${variation === item ? C.primary : C.border}`, color: variation === item ? C.primary : C.gray, fontSize: 12, fontWeight: 700 }}>{item}</button>)}</div>
          </div>
          <div style={{ background: C.card, borderRadius: 16, padding: 16, marginTop: 20, border: `1px solid ${C.border}`, display: "flex", gap: 12, alignItems: "center" }}><Av initials="ZC" color={C.purple} size={44} /><div style={{ flex: 1 }}><p style={{ fontSize: 13, fontWeight: 800, color: C.ink }}>Zuri Craft House <CheckCircle size={12} color={C.primary} fill={C.primaryLight} /></p><p style={{ fontSize: 11, color: C.muted, marginTop: 3 }}>Verified seller · Usually responds in 20 min</p></div><Btn size="sm" variant="ghost" icon={<MessageCircle size={13} />}>Message</Btn></div>
          <div style={{ background: C.primaryLight, borderRadius: 15, padding: 15, marginTop: 14, display: "flex", gap: 10 }}><Truck size={19} color={C.primary} /><div><p style={{ fontSize: 13, fontWeight: 700, color: C.ink }}>Delivery from ₦2,500</p><p style={{ fontSize: 11, color: C.gray, marginTop: 3 }}>Estimated arrival: 2–3 business days · Lagos</p></div></div>
          <div style={{ display: "grid", gridTemplateColumns: "1fr 2fr", gap: 10, marginTop: 20 }}><Btn variant="secondary" onClick={() => { onAdd(); goTo("cart"); }}>Buy now</Btn><Btn onClick={onAdd} icon={<ShoppingCart size={16} />}>Add to cart</Btn></div>
          <p style={{ textAlign: "center", fontSize: 10, color: C.muted, marginTop: 10 }}>Prototype actions use sample data; no payment will be processed.</p>
        </div>
      </div>
    </main>
  );
}

function CartScreen({ goTo, bp }: { goTo: (s: Screen) => void; bp: BP }) {
  return (
    <main style={{ maxWidth: 1040, margin: "0 auto", padding: bp.isMobile ? "22px 16px 90px" : "34px 32px" }}>
      <h1 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 26, color: C.ink }}>Your cart</h1>
      <p style={{ fontSize: 13, color: C.gray, marginTop: 4 }}>1 item from 1 local seller</p>
      <div style={{ display: "grid", gridTemplateColumns: bp.isDesktop ? "1.5fr .7fr" : "1fr", gap: 20, marginTop: 22 }}>
        <Card>
          <div style={{ display: "flex", gap: 15, alignItems: "center" }}>
            <img src={products[0].image} alt={products[0].name} style={{ width: 92, height: 92, borderRadius: 14, objectFit: "cover" }} />
            <div style={{ flex: 1 }}><p style={{ fontSize: 11, color: C.muted }}>Zuri Craft House</p><p style={{ fontSize: 15, fontWeight: 800, color: C.ink, marginTop: 4 }}>{products[0].name}</p><p style={{ fontSize: 11, color: C.gray, marginTop: 3 }}>Natural · In stock</p><div style={{ display: "flex", alignItems: "center", gap: 8, marginTop: 11 }}><button style={{ width: 26, height: 26, borderRadius: 8, background: "#F4F6FB" }}>−</button><span style={{ fontSize: 13, fontWeight: 700 }}>1</span><button style={{ width: 26, height: 26, borderRadius: 8, background: "#F4F6FB" }}>+</button></div></div>
            <div style={{ textAlign: "right" }}><p style={{ fontWeight: 800, color: C.ink }}>₦18,500</p><button style={{ color: C.red, fontSize: 11, marginTop: 24 }}>Remove</button></div>
          </div>
        </Card>
        <Card>
          <h2 style={{ fontSize: 16, fontWeight: 800, color: C.ink }}>Order summary</h2>
          {[["Subtotal", "₦18,500"], ["Delivery estimate", "₦2,500"], ["Buyer protection", "Included"]].map(([label, value]) => <div key={label} style={{ display: "flex", justifyContent: "space-between", marginTop: 14, fontSize: 12, color: C.gray }}><span>{label}</span><strong style={{ color: value === "Included" ? C.green : C.ink }}>{value}</strong></div>)}
          <div style={{ borderTop: `1px solid ${C.border}`, marginTop: 16, paddingTop: 16, display: "flex", justifyContent: "space-between" }}><span style={{ fontWeight: 800, color: C.ink }}>Total</span><span style={{ fontSize: 18, fontWeight: 800, color: C.primary }}>₦21,000</span></div>
          <div style={{ marginTop: 18 }}><Btn size="lg" onClick={() => goTo("checkout")}>Continue to checkout</Btn></div>
          <button onClick={() => goTo("market-home")} style={{ width: "100%", marginTop: 12, color: C.primary, fontSize: 12, fontWeight: 700 }}>Keep shopping</button>
        </Card>
      </div>
    </main>
  );
}

function CheckoutScreen({ goTo, bp }: { goTo: (s: Screen) => void; bp: BP }) {
  const [delivery, setDelivery] = useState("standard");
  return (
    <main style={{ maxWidth: 1040, margin: "0 auto", padding: bp.isMobile ? "20px 16px 90px" : "32px" }}>
      <button onClick={() => goTo("cart")} style={{ display: "flex", gap: 6, alignItems: "center", color: C.gray, fontSize: 12, marginBottom: 14 }}><ArrowLeft size={15} /> Back to cart</button>
      <h1 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontSize: 26, fontWeight: 800, color: C.ink }}>Checkout</h1>
      <div style={{ display: "grid", gridTemplateColumns: bp.isDesktop ? "1.35fr .65fr" : "1fr", gap: 20, marginTop: 20 }}>
        <div style={{ display: "flex", flexDirection: "column", gap: 16 }}>
          <Card><div style={{ display: "flex", gap: 10, alignItems: "center", marginBottom: 17 }}><div style={{ width: 30, height: 30, borderRadius: 9, background: C.primaryLight, color: C.primary, fontSize: 12, fontWeight: 800, display: "flex", alignItems: "center", justifyContent: "center" }}>1</div><h2 style={{ fontSize: 15, fontWeight: 800, color: C.ink }}>Delivery details</h2></div><div style={{ display: "grid", gridTemplateColumns: bp.isMobile ? "1fr" : "1fr 1fr", gap: 12 }}><Input label="Full name" defaultValue="Amara Diallo" /><Input label="Phone number" defaultValue="+234 800 000 0000" /><div style={{ gridColumn: bp.isMobile ? "auto" : "1 / -1" }}><Input label="Delivery address" defaultValue="14 Admiralty Way, Lekki Phase 1" /></div><Input label="City" defaultValue="Lagos" /><Input label="Delivery note" placeholder="Landmark or special instruction" /></div></Card>
          <Card><div style={{ display: "flex", gap: 10, alignItems: "center", marginBottom: 13 }}><div style={{ width: 30, height: 30, borderRadius: 9, background: C.primaryLight, color: C.primary, fontSize: 12, fontWeight: 800, display: "flex", alignItems: "center", justifyContent: "center" }}>2</div><h2 style={{ fontSize: 15, fontWeight: 800, color: C.ink }}>Delivery method</h2></div>{[{ id: "standard", title: "Standard delivery", sub: "2–3 business days", price: "₦2,500" }, { id: "pickup", title: "Pick up from seller", sub: "Ready tomorrow", price: "Free" }].map(option => <button key={option.id} onClick={() => setDelivery(option.id)} style={{ width: "100%", padding: 14, borderRadius: 13, border: `1.5px solid ${delivery === option.id ? C.primary : C.border}`, background: delivery === option.id ? C.primaryLight : "#fff", display: "flex", alignItems: "center", gap: 11, textAlign: "left", marginTop: 8 }}><div style={{ width: 18, height: 18, borderRadius: "50%", border: `5px solid ${delivery === option.id ? C.primary : "#D7DBE6"}` }} /><div style={{ flex: 1 }}><p style={{ fontSize: 13, fontWeight: 700, color: C.ink }}>{option.title}</p><p style={{ fontSize: 11, color: C.muted }}>{option.sub}</p></div><strong style={{ fontSize: 12, color: C.ink }}>{option.price}</strong></button>)}</Card>
          <Card><div style={{ display: "flex", gap: 10, alignItems: "center", marginBottom: 13 }}><div style={{ width: 30, height: 30, borderRadius: 9, background: C.primaryLight, color: C.primary, fontSize: 12, fontWeight: 800, display: "flex", alignItems: "center", justifyContent: "center" }}>3</div><h2 style={{ fontSize: 15, fontWeight: 800, color: C.ink }}>Payment</h2></div><div style={{ padding: 14, borderRadius: 13, border: `1.5px solid ${C.primary}`, background: C.primaryLight, display: "flex", alignItems: "center", gap: 11 }}><Wallet size={18} color={C.primary} /><div><p style={{ fontSize: 13, fontWeight: 700, color: C.ink }}>Hivorr Wallet</p><p style={{ fontSize: 11, color: C.gray }}>Protected payment · Sample balance ₦84,300</p></div></div></Card>
        </div>
        <Card><h2 style={{ fontSize: 15, fontWeight: 800, color: C.ink }}>Review order</h2><div style={{ display: "flex", gap: 10, marginTop: 16 }}><img src={products[0].image} alt="" style={{ width: 58, height: 58, borderRadius: 10, objectFit: "cover" }} /><div><p style={{ fontSize: 12, fontWeight: 700, color: C.ink }}>{products[0].name}</p><p style={{ fontSize: 11, color: C.muted, marginTop: 3 }}>Qty 1 · Natural</p></div></div><div style={{ borderTop: `1px solid ${C.border}`, marginTop: 16, paddingTop: 14, display: "flex", justifyContent: "space-between" }}><strong>Total</strong><strong style={{ color: C.primary }}>₦21,000</strong></div><div style={{ marginTop: 18 }}><Btn size="lg" onClick={() => goTo("order-confirmation")} icon={<Lock size={14} />}>Place sample order</Btn></div><p style={{ fontSize: 10, color: C.muted, lineHeight: 1.5, textAlign: "center", marginTop: 10 }}>Prototype only. This button does not charge a card or create a real order.</p></Card>
      </div>
    </main>
  );
}

function OrderConfirmation({ goTo }: { goTo: (s: Screen) => void }) {
  const { isMobile } = useBreakpoint();
  return <main style={{ minHeight: "calc(100vh - 68px)", display: "flex", justifyContent: "center", alignItems: "center", padding: isMobile ? "16px 16px 90px" : 20 }}><Card padding={isMobile ? 22 : 34}><div style={{ textAlign: "center", maxWidth: 440 }}><div style={{ width: 76, height: 76, borderRadius: 24, background: C.greenLight, display: "flex", alignItems: "center", justifyContent: "center", margin: "0 auto 20px" }}><CheckCircle size={38} color={C.green} /></div><Pill label="SAMPLE ORDER CONFIRMED" color={C.green} bg={C.greenLight} /><h1 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, color: C.ink, fontSize: isMobile ? 23 : 27, marginTop: 12 }}>Your order is on its way.</h1><p style={{ fontSize: 14, lineHeight: 1.65, color: C.gray, marginTop: 10 }}>Order <strong style={{ color: C.ink }}>#HV-20481</strong> has been sent to Zuri Craft House. We’ll notify you when it’s ready for delivery.</p><div style={{ background: "#F8F9FC", borderRadius: 14, padding: 15, marginTop: 20, textAlign: "left", display: "flex", gap: 10 }}><Truck size={19} color={C.primary} /><div><p style={{ fontSize: 12, fontWeight: 700, color: C.ink }}>Estimated delivery</p><p style={{ fontSize: 12, color: C.gray, marginTop: 2 }}>Thursday, 18 July · Lagos</p></div></div><div style={{ display: "grid", gridTemplateColumns: isMobile ? "1fr" : "1fr 1fr", gap: 9, marginTop: 20 }}><Btn variant="secondary" onClick={() => goTo("market-home")}>Back to market</Btn><Btn onClick={() => goTo("order-detail")}>View order</Btn></div></div></Card></main>;
}

function OrdersScreen({ bp }: { bp: BP }) {
  const steps = [["Order confirmed", "Today, 10:42", true], ["Seller preparing item", "Expected today", true], ["Picked up by courier", "Pending", false], ["Delivered", "Expected Jul 18", false]];
  return <main style={{ maxWidth: 1050, margin: "0 auto", padding: bp.isMobile ? "24px 16px 90px" : "34px 32px" }}><div><h1 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontSize: 26, fontWeight: 800, color: C.ink }}>Orders</h1><p style={{ fontSize: 13, color: C.gray, marginTop: 4 }}>Purchases and delivery updates in one place</p></div><div style={{ display: "grid", gridTemplateColumns: bp.isDesktop ? ".7fr 1.3fr" : "1fr", gap: 18, marginTop: 22 }}><Card><Pill label="IN PROGRESS" color={C.orange} bg={C.orangeLight} /><div style={{ display: "flex", gap: 12, marginTop: 14 }}><img src={products[0].image} alt="" style={{ width: 72, height: 72, borderRadius: 12, objectFit: "cover" }} /><div><p style={{ fontSize: 14, fontWeight: 800, color: C.ink }}>{products[0].name}</p><p style={{ fontSize: 11, color: C.muted, marginTop: 4 }}>#HV-20481 · ₦21,000</p><p style={{ fontSize: 11, color: C.gray, marginTop: 8 }}>Zuri Craft House</p></div></div><div style={{ marginTop: 14 }}><Btn size="sm" variant="secondary" icon={<MessageCircle size={12} />}>Contact seller</Btn></div></Card><Card><h2 style={{ fontSize: 16, fontWeight: 800, color: C.ink }}>Delivery tracking</h2><div style={{ marginTop: 18 }}>{steps.map(([title, sub, done], i) => <div key={title as string} style={{ display: "flex", gap: 12, minHeight: 62 }}><div style={{ display: "flex", flexDirection: "column", alignItems: "center" }}><div style={{ width: 24, height: 24, borderRadius: "50%", background: done ? C.primary : "#E5E7EB", display: "flex", alignItems: "center", justifyContent: "center" }}>{done ? <Check size={12} color="#fff" /> : <span style={{ width: 6, height: 6, borderRadius: "50%", background: C.muted }} />}</div>{i < steps.length - 1 && <div style={{ width: 2, flex: 1, background: done ? C.primary : "#E5E7EB" }} />}</div><div><p style={{ fontSize: 13, fontWeight: 700, color: done ? C.ink : C.muted }}>{title as string}</p><p style={{ fontSize: 11, color: C.muted, marginTop: 3 }}>{sub as string}</p></div></div>)}</div></Card></div></main>;
}

function OrderDetail({ goTo, bp }: { goTo: (s: Screen) => void; bp: BP }) {
  return <main style={{ maxWidth: 960, margin: "0 auto", padding: bp.isMobile ? "22px 16px 90px" : "32px" }}><button onClick={() => goTo("orders")} style={{ display: "flex", gap: 6, alignItems: "center", fontSize: 12, color: C.gray }}><ArrowLeft size={14} /> My orders</button><div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", gap: 12, flexWrap: "wrap", marginTop: 16 }}><div><Pill label="PROCESSING" color={C.orange} bg={C.orangeLight} /><h1 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontSize: 26, fontWeight: 800, color: C.ink, marginTop: 9 }}>Order #HV-20481</h1><p style={{ fontSize: 12, color: C.muted, marginTop: 4 }}>Placed today at 10:42 · Illustrative prototype order</p></div><Btn size="sm" variant="secondary" icon={<MessageCircle size={12} />}>Contact seller</Btn></div><div style={{ display: "grid", gridTemplateColumns: bp.isDesktop ? "1.2fr .8fr" : "1fr", gap: 18, marginTop: 20 }}><Card><h2 style={{ fontSize: 15, fontWeight: 800, color: C.ink }}>Items</h2><div style={{ display: "flex", gap: 12, marginTop: 14 }}><img src={products[0].image} alt="" style={{ width: 72, height: 72, borderRadius: 12, objectFit: "cover" }} /><div style={{ flex: 1 }}><p style={{ fontSize: 13, fontWeight: 700, color: C.ink }}>{products[0].name}</p><p style={{ fontSize: 11, color: C.muted, marginTop: 3 }}>Natural · Qty 1</p><p style={{ fontSize: 12, fontWeight: 800, color: C.ink, marginTop: 10 }}>₦18,500</p></div></div><div style={{ borderTop: `1px solid ${C.border}`, marginTop: 16, paddingTop: 14 }}>{[["Subtotal", "₦18,500"], ["Delivery", "₦2,500"], ["Total", "₦21,000"]].map(([l,v]) => <div key={l} style={{ display: "flex", justifyContent: "space-between", marginTop: 8, fontSize: 12, fontWeight: l === "Total" ? 800 : 500, color: l === "Total" ? C.ink : C.gray }}><span>{l}</span><span>{v}</span></div>)}</div></Card><div style={{ display: "flex", flexDirection: "column", gap: 14 }}><Card><h2 style={{ fontSize: 15, fontWeight: 800, color: C.ink }}>Delivery details</h2><p style={{ fontSize: 12, color: C.gray, lineHeight: 1.55, marginTop: 10 }}>Amara Diallo<br/>14 Admiralty Way, Lekki Phase 1<br/>Lagos</p></Card><Card><h2 style={{ fontSize: 15, fontWeight: 800, color: C.ink }}>Payment</h2><p style={{ fontSize: 12, color: C.gray, marginTop: 8 }}>Hivorr Wallet · Simulated payment</p><p style={{ fontSize: 11, color: C.green, fontWeight: 700, marginTop: 6 }}>Payment authorized</p></Card></div></div></main>;
}

function SellerHome({ goTo, bp, categories }: { goTo: (s: Screen) => void; bp: BP; categories: SellerCategory[] }) {
  const listings = [
    { name: "Handwoven Market Tote", stock: 12, status: "Published", color: C.green, bg: C.greenLight, categoryId: "fashion", subcategoryId: "bags" },
    { name: "Indigo Carry Basket", stock: 4, status: "Pending review", color: C.orange, bg: C.orangeLight, categoryId: "home", subcategoryId: "decor" },
    { name: "Artisan Storage Set", stock: 0, status: "Unavailable", color: C.muted, bg: "#F4F6FB", categoryId: "home", subcategoryId: "furniture" },
  ];
  const [editingListing,setEditingListing]=useState<(typeof listings)[number]|null>(null);
  const [setupOpen,setSetupOpen]=useState(false);
  const [editCategoryId,setEditCategoryId]=useState("fashion");
  const [editSubcategoryId,setEditSubcategoryId]=useState("bags");
  const openListingEditor=(listing:(typeof listings)[number])=>{setEditingListing(listing);setEditCategoryId(listing.categoryId);setEditSubcategoryId(listing.subcategoryId);};
  return <main style={{ maxWidth: 1140, margin: "0 auto", padding: bp.isMobile ? "22px 16px 90px" : "30px 32px" }}><ActivityHero bp={bp} eyebrow="I WANT TO SELL" name="Zuri Craft House" description="Your store is growing. Review sales, fulfil orders, and keep your best products visible to local buyers." image={activityHeroImages.selling} imageAlt="Small business owner welcoming customers from behind a shop counter" gradient="linear-gradient(125deg,#5B21B6 0%,#7C3AED 58%,#9B66F3 100%)" action={<Btn onClick={() => goTo("seller-listing")} icon={<Plus size={15} />}>New listing</Btn>} /><div style={{ display: "grid", gridTemplateColumns: bp.isMobile ? "repeat(2,1fr)" : "repeat(4,1fr)", gap: 12, marginTop: 22 }}>{[{ l: "Sales this month", v: "₦284k", i: Wallet, c: C.green, b: C.greenLight }, { l: "Open orders", v: "8", i: Package, c: C.primary, b: C.primaryLight }, { l: "Published", v: "14", i: Store, c: C.purple, b: C.purpleLight }, { l: "Customer messages", v: "3", i: MessageCircle, c: C.orange, b: C.orangeLight }].map(item => <StatCard key={item.l} label={item.l} value={item.v} icon={<item.i size={19} color={item.c} />} color={item.c} bg={item.b} />)}</div><div style={{ display: "grid", gridTemplateColumns: bp.isDesktop ? "1.35fr .65fr" : "1fr", gap: 18, marginTop: 20 }}><Card><div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}><h2 style={{ fontSize: 16, fontWeight: 800, color: C.ink }}>Your listings</h2><button onClick={() => goTo("seller-products")} style={{ color: C.primary, fontSize: 12, fontWeight: 700 }}>Manage all</button></div><div style={{ marginTop: 12 }}>{listings.map((listing, i) => <div key={listing.name} style={{ display: "flex", alignItems: "center", gap: 12, padding: "12px 0", borderTop: i ? `1px solid ${C.border}` : "none",flexWrap:bp.isMobile?"wrap":"nowrap" }}><img src={products[i % products.length].image} alt="" style={{ width: 52, height: 52, borderRadius: 10, objectFit: "cover",flexShrink:0 }} /><div style={{ flex: 1,minWidth:140 }}><p style={{ fontSize: 13, fontWeight: 700, color: C.ink }}>{listing.name}</p><p style={{ fontSize: 11, color: C.muted, marginTop: 3 }}>{listing.stock} in stock</p></div><Pill label={listing.status} color={listing.color} bg={listing.bg} /><button aria-label={`Edit ${listing.name}`} onClick={()=>openListingEditor(listing)} style={{ width:30,height:30,borderRadius:9,background:"#F4F6FB",display:"flex",alignItems:"center",justifyContent:"center",flexShrink:0 }}><Edit3 size={14} color={C.muted} /></button></div>)}</div></Card><div style={{ display: "flex", flexDirection: "column", gap: 14 }}><Card><h2 style={{ fontSize: 15, fontWeight: 800, color: C.ink }}>Store readiness</h2><div style={{ height: 7, background: "#E6E9F2", borderRadius: 5, marginTop: 13, overflow: "hidden" }}><div style={{ width: "82%", height: "100%", background: C.green, borderRadius: 5 }} /></div><p style={{ fontSize: 11, color: C.gray, lineHeight: 1.5, marginTop: 9 }}>Add a return policy and verify your business address to complete setup.</p><div style={{ marginTop: 12 }}><Btn size="sm" variant="secondary" onClick={()=>setSetupOpen(true)}>Complete setup</Btn></div></Card><Card><h2 style={{ fontSize: 15, fontWeight: 800, color: C.ink }}>Fulfilment today</h2><p style={{ fontSize: 30, fontWeight: 800, color: C.primary, marginTop: 8 }}>3</p><p style={{ fontSize: 11, color: C.gray }}>orders need packing before 4 PM</p></Card></div></div>{editingListing&&<PrototypeDialog title={`Edit ${editingListing.name}`} eyebrow="SELLER LISTING" onClose={()=>setEditingListing(null)} footer={<><Btn variant="ghost" onClick={()=>setEditingListing(null)}>Cancel</Btn><Btn onClick={()=>setEditingListing(null)} icon={<Check size={14}/>}>Save changes</Btn></>}><div style={{ display:"flex",flexDirection:"column",gap:14 }}><Input label="Product title" defaultValue={editingListing.name}/><ProductTaxonomyFields categories={categories} categoryId={editCategoryId} subcategoryId={editSubcategoryId} onCategoryChange={setEditCategoryId} onSubcategoryChange={setEditSubcategoryId} isMobile={bp.isMobile}/><div style={{ display:"grid",gridTemplateColumns:bp.isMobile?"1fr":"1fr 1fr",gap:12 }}><Input label="Stock quantity" defaultValue={String(editingListing.stock)} type="number"/><Input label="Publication status" defaultValue={editingListing.status}/></div><Input label="Seller note" rows={3} placeholder="Update product details, availability, or review notes"/><p style={{ fontSize:10,color:C.muted }}>Prototype changes are not published to a live marketplace.</p></div></PrototypeDialog>}{setupOpen&&<PrototypeDialog title="Complete store setup" eyebrow="2 ITEMS REMAINING" onClose={()=>setSetupOpen(false)} footer={<><Btn variant="ghost" onClick={()=>setSetupOpen(false)}>Later</Btn><Btn onClick={()=>setSetupOpen(false)} icon={<Check size={14}/>}>Save setup</Btn></>}><div style={{ display:"flex",flexDirection:"column",gap:14 }}><div style={{ background:C.orangeLight,borderRadius:13,padding:13 }}><p style={{ fontSize:12,fontWeight:800,color:C.ink }}>Finish your seller profile</p><p style={{ fontSize:11,color:C.gray,lineHeight:1.5,marginTop:4 }}>Add the missing return policy and verify the business address shown to Hivorr.</p></div><Input label="Business address" defaultValue="18 Admiralty Way, Lekki, Lagos"/><Input label="Return policy" rows={4} placeholder="Describe eligible returns, timing, and product condition requirements"/><p style={{ fontSize:10,color:C.muted }}>Saving updates this prototype only and does not complete real business verification.</p></div></PrototypeDialog>}</main>;
}

const sellerProductRows = [
  { name: "Handwoven Market Tote", sku: "ZC-TOTE-01", cost: 10500, price: 18500, stock: 12, sold: 18, status: "Published" },
  { name: "Ankara Weekend Set", sku: "ZC-ANK-04", cost: 19000, price: 32000, stock: 7, sold: 9, status: "Published" },
  { name: "Artisan Storage Set", sku: "ZC-HOME-08", cost: 14000, price: 24500, stock: 0, sold: 5, status: "Unavailable" },
];

function SellerProducts({ goTo, bp, categories }: { goTo: (s: Screen) => void; bp: BP; categories: SellerCategory[] }) {
  const [editingProduct,setEditingProduct]=useState<(typeof sellerProductRows)[number]|null>(null);
  const [editCategoryId,setEditCategoryId]=useState("fashion");
  const [editSubcategoryId,setEditSubcategoryId]=useState("bags");
  const openProductEditor=(product:(typeof sellerProductRows)[number],index:number)=>{setEditingProduct(product);const categoryId=index===1?"fashion":"home";setEditCategoryId(categoryId);setEditSubcategoryId(categoryId==="fashion"?(index===1?"clothing":"bags"):(index===2?"furniture":"decor"));};
  return <main style={{ maxWidth: 1160, margin: "0 auto", padding: bp.isMobile ? "22px 16px 90px" : "30px 32px" }}><div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-end", gap: 12, flexWrap:"wrap" }}><div><h1 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontSize: 26, fontWeight: 800, color: C.ink }}>Products</h1><p style={{ fontSize: 13, color: C.gray, marginTop: 4 }}>Manage pricing, publication, stock, and product profitability.</p></div><Btn onClick={() => goTo("seller-listing")} icon={<Plus size={14} />}>Add Product</Btn></div><Card padding={0} style={{ marginTop:20, overflow:"hidden" }}><div style={{ padding: 16, display: "flex", gap: 10, borderBottom: `1px solid ${C.border}` }}><div style={{ flex: 1, minWidth:0, background: "#F4F6FB", borderRadius: 10, padding: "9px 12px", display: "flex", gap: 7 }}><Search size={14} color={C.muted} /><input placeholder="Search products or SKU" style={{ border: 0, outline: 0, background: "transparent", width: "100%", minWidth:0, fontSize: 12 }} /></div><Btn size="sm" variant="secondary" icon={<Filter size={12} />}>Filter</Btn></div><div style={{ overflowX: "auto" }}><table style={{ width: "100%", borderCollapse: "collapse", minWidth: 760 }}><thead><tr style={{ background: "#F8F9FC" }}>{["Product", "SKU", "Cost", "Selling price", "Unit gross profit", "Stock", "Status", ""].map(h => <th key={h} style={{ textAlign: "left", padding: "11px 14px", color: C.muted, fontSize: 11 }}>{h}</th>)}</tr></thead><tbody>{sellerProductRows.map((p,i) => <tr key={p.sku} style={{ borderTop: `1px solid ${C.border}` }}><td style={{ padding: 14 }}><div style={{ display: "flex", gap: 9, alignItems: "center" }}><img src={products[i].image} alt="" style={{ width: 42, height: 42, objectFit: "cover", borderRadius: 9 }} /><span style={{ fontSize: 12, fontWeight: 700, color: C.ink }}>{p.name}</span></div></td><td style={{ padding: 14, fontSize: 11, color: C.muted }}>{p.sku}</td><td style={{ padding: 14, fontSize: 12 }}>₦{p.cost.toLocaleString()}</td><td style={{ padding: 14, fontSize: 12, fontWeight: 700 }}>₦{p.price.toLocaleString()}</td><td style={{ padding: 14, fontSize: 12, fontWeight: 800, color: C.green }}>₦{(p.price-p.cost).toLocaleString()}</td><td style={{ padding: 14, fontSize: 12, color: p.stock < 5 ? C.red : C.ink }}>{p.stock}</td><td style={{ padding: 14 }}><Pill label={p.status} color={p.status === "Published" ? C.green : C.muted} bg={p.status === "Published" ? C.greenLight : "#F4F6FB"} /></td><td style={{ padding: 14 }}><button aria-label={`Edit ${p.name}`} onClick={()=>openProductEditor(p,i)} style={{ width:30,height:30,borderRadius:9,background:"#F4F6FB",display:"flex",alignItems:"center",justifyContent:"center" }}><Edit3 size={14} color={C.muted} /></button></td></tr>)}</tbody></table></div></Card><p style={{ fontSize: 10, color: C.muted, marginTop: 10 }}>Acquisition costs and profit estimates are private seller data. Gross profit excludes fees, taxes, and other operating expenses.</p>{editingProduct&&<PrototypeDialog title={`Edit ${editingProduct.name}`} eyebrow={editingProduct.sku} onClose={()=>setEditingProduct(null)} footer={<><Btn variant="ghost" onClick={()=>setEditingProduct(null)}>Cancel</Btn><Btn onClick={()=>setEditingProduct(null)} icon={<Check size={14}/>}>Save changes</Btn></>}><div style={{ display:"flex",flexDirection:"column",gap:14 }}><Input label="Product title" defaultValue={editingProduct.name}/><ProductTaxonomyFields categories={categories} categoryId={editCategoryId} subcategoryId={editSubcategoryId} onCategoryChange={setEditCategoryId} onSubcategoryChange={setEditSubcategoryId} isMobile={bp.isMobile}/><div style={{ display:"grid",gridTemplateColumns:bp.isMobile?"1fr":"1fr 1fr",gap:12 }}><Input label="Selling price" defaultValue={`₦${editingProduct.price.toLocaleString()}`}/><Input label="Stock" type="number" defaultValue={String(editingProduct.stock)}/></div><p style={{ fontSize:10,color:C.muted }}>Only active administrator-managed categories can be selected.</p></div></PrototypeDialog>}</main>;
}

function SellerOrders({ goTo, bp }: { goTo: (s: Screen) => void; bp: BP }) {
  const rows = [{ id: "#HV-20481", customer: "Amara Diallo", total: "₦21,000", status: "Preparing", color: C.orange, bg: C.orangeLight }, { id: "#HV-20472", customer: "Tunde Bello", total: "₦32,000", status: "Ready for dispatch", color: C.primary, bg: C.primaryLight }, { id: "#HV-20439", customer: "Lola Mensah", total: "₦46,500", status: "Completed", color: C.green, bg: C.greenLight }];
  return <main style={{ maxWidth: 1100, margin: "0 auto", padding: bp.isMobile ? "22px 16px 90px" : "30px 32px" }}><div style={{ display: "flex", justifyContent: "space-between", alignItems: "center",gap:12,flexWrap:"wrap" }}><div><h1 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontSize: 26, fontWeight: 800, color: C.ink }}>Seller orders</h1><p style={{ fontSize: 13, color: C.gray, marginTop: 4 }}>Process orders without entering logistics-provider controls.</p></div><Btn size="sm" variant="secondary" onClick={() => goTo("seller-invoices")} icon={<FileText size={13} />}>Invoices</Btn></div><div style={{ display: "grid", gridTemplateColumns: bp.isMobile ? "repeat(2,1fr)" : "repeat(4,1fr)", gap: 12, marginTop: 20 }}>{[["New orders","3"],["Preparing","5"],["Ready","2"],["Completed","46"]].map(([l,v],i)=><StatCard key={l} label={l} value={v} icon={[<Package size={17} color={C.primary}/>,<Clock size={17} color={C.orange}/>,<Truck size={17} color={C.purple}/>,<CheckCircle size={17} color={C.green}/>][i]} color={[C.primary,C.orange,C.purple,C.green][i]} bg={[C.primaryLight,C.orangeLight,C.purpleLight,C.greenLight][i]}/>)}</div><Card style={{ marginTop:18 }}><div style={{ display: "flex", gap: 8, marginBottom: 8,overflowX:"auto",paddingBottom:4 }}>{["All","New","Preparing","Ready","Completed"].map((x,i)=><button key={x} style={{ padding:"7px 10px", borderRadius:18, background:i===0?C.primary:C.card, color:i===0?"#fff":C.gray, fontSize:11, fontWeight:700,whiteSpace:"nowrap" }}>{x}</button>)}</div>{rows.map((r,i)=><div key={r.id} style={{ display:"flex", alignItems:"center", gap:12, padding:"14px 0", borderTop:i?`1px solid ${C.border}`:"none",flexWrap:bp.isMobile?"wrap":"nowrap" }}><div style={{ width:38,height:38,borderRadius:11,background:C.primaryLight,display:"flex",alignItems:"center",justifyContent:"center",flexShrink:0 }}><Package size={16} color={C.primary}/></div><div style={{ flex:1,minWidth:bp.isMobile?150:0 }}><p style={{ fontSize:13,fontWeight:800,color:C.ink }}>{r.id}</p><p style={{ fontSize:11,color:C.muted,marginTop:3 }}>{r.customer} · 1 item</p></div><strong style={{ fontSize:13 }}>{r.total}</strong><Pill label={r.status} color={r.color} bg={r.bg}/><Btn size="sm" variant="ghost">View</Btn></div>)}</Card></main>;
}

function SellerInventory({ bp }: { bp: BP }) {
  const [inventory,setInventory]=useState(sellerProductRows);
  const [adjusting,setAdjusting]=useState<(typeof sellerProductRows)[number]|null>(null);
  const [quantity,setQuantity]=useState("");
  const openAdjustment=(product:(typeof sellerProductRows)[number])=>{setAdjusting(product);setQuantity(String(product.stock));};
  const saveAdjustment=()=>{
    if(!adjusting)return;
    const next=Math.max(0,Number.parseInt(quantity,10)||0);
    setInventory(rows=>rows.map(row=>row.sku===adjusting.sku?{...row,stock:next}:row));
    setAdjusting(null);
  };
  const totalUnits=inventory.reduce((sum,item)=>sum+item.stock,0);
  const stockValue=inventory.reduce((sum,item)=>sum+item.stock*item.cost,0);
  return <main style={{ maxWidth: 1080, margin:"0 auto", padding:bp.isMobile?"22px 16px 90px":"30px 32px" }}><div><h1 style={{ fontFamily:"'Plus Jakarta Sans',sans-serif",fontSize:26,fontWeight:800,color:C.ink }}>Inventory</h1><p style={{ fontSize:13,color:C.gray,marginTop:4 }}>Illustrative stock levels and manual adjustment history.</p></div><div style={{ display:"grid",gridTemplateColumns:bp.isMobile?"repeat(2,1fr)":"repeat(4,1fr)",gap:12,marginTop:20 }}>{[["Units in stock",String(totalUnits)],["Low stock",String(inventory.filter(item=>item.stock>0&&item.stock<8).length)],["Out of stock",String(inventory.filter(item=>item.stock===0).length)],["Stock value",`₦${Math.round(stockValue/1000)}k`]].map(([l,v],i)=><StatCard key={l} label={l} value={v} icon={<Boxes size={18} color={[C.primary,C.orange,C.red,C.green][i]}/>} color={[C.primary,C.orange,C.red,C.green][i]} bg={[C.primaryLight,C.orangeLight,C.redLight,C.greenLight][i]}/>)}</div><Card style={{ marginTop:18 }}><h2 style={{ fontSize:15,fontWeight:800,color:C.ink }}>Stock control</h2>{inventory.map((p,i)=><div key={p.sku} style={{ display:"flex",alignItems:"center",gap:12,padding:"13px 0",borderTop:i?`1px solid ${C.border}`:"none",flexWrap:bp.isMobile?"wrap":"nowrap" }}><img src={products[i].image} alt="" style={{ width:44,height:44,borderRadius:9,objectFit:"cover",flexShrink:0 }}/><div style={{ flex:1,minWidth:bp.isMobile?150:0 }}><p style={{ fontSize:12,fontWeight:700,color:C.ink }}>{p.name}</p><p style={{ fontSize:10,color:C.muted }}>{p.sku} · Last adjusted 2d ago</p></div><Pill label={p.stock===0?"Out of stock":p.stock<8?"Low stock":"In stock"} color={p.stock===0?C.red:p.stock<8?C.orange:C.green} bg={p.stock===0?C.redLight:p.stock<8?C.orangeLight:C.greenLight}/><strong>{p.stock}</strong><Btn size="sm" variant="secondary" onClick={()=>openAdjustment(p)}>Adjust</Btn></div>)}</Card>{adjusting&&<PrototypeDialog title="Adjust inventory" eyebrow={adjusting.sku} onClose={()=>setAdjusting(null)} footer={<><Btn variant="ghost" onClick={()=>setAdjusting(null)}>Cancel</Btn><Btn onClick={saveAdjustment} icon={<Check size={14}/>}>Save quantity</Btn></>}><div style={{ display:"flex",flexDirection:"column",gap:14 }}><div style={{ display:"flex",alignItems:"center",gap:12,background:"#F8F9FC",padding:12,borderRadius:13 }}><Boxes size={20} color={C.primary}/><div><p style={{ fontSize:13,fontWeight:800,color:C.ink }}>{adjusting.name}</p><p style={{ fontSize:10,color:C.muted }}>Current stock: {adjusting.stock} units</p></div></div><Input label="New quantity on hand" type="number" min="0" value={quantity} onChange={e=>setQuantity(e.target.value)}/><Input label="Adjustment note" placeholder="e.g. Stock count, return, or damaged item"/><p style={{ fontSize:10,color:C.muted }}>This updates the displayed prototype inventory only.</p></div></PrototypeDialog>}</main>;
}

function SellerInvoices({ bp }: { bp: BP }) {
  const invoices=[
    {id:"INV-20481",order:"#HV-20481",issued:"Today",total:"₦21,000",payment:"Authorized",customer:"Adaeze Okafor",item:"Indigo Carry Basket",subtotal:"₦18,500",delivery:"₦2,500"},
    {id:"INV-20472",order:"#HV-20472",issued:"Yesterday",total:"₦32,000",payment:"Paid",customer:"Tomi Adebayo",item:"Handwoven Market Tote",subtotal:"₦29,500",delivery:"₦2,500"},
    {id:"INV-20439",order:"#HV-20439",issued:"Jul 12",total:"₦46,500",payment:"Paid",customer:"Chidi Eze",item:"Artisan Home Collection",subtotal:"₦43,000",delivery:"₦3,500"},
  ];
  const [preview,setPreview]=useState<(typeof invoices)[number]|null>(null);
  const [sent,setSent]=useState(false);
  const openPreview=(invoice:(typeof invoices)[number])=>{setPreview(invoice);setSent(false);};
  return <main style={{ maxWidth:1000,margin:"0 auto",padding:bp.isMobile?"22px 16px 90px":"30px 32px" }}><div><h1 style={{ fontFamily:"'Plus Jakarta Sans',sans-serif",fontSize:26,fontWeight:800,color:C.ink }}>Invoices & documents</h1><p style={{ fontSize:13,color:C.gray,marginTop:4 }}>Order documents do not indicate payment unless the payment status is confirmed.</p></div><Card padding={0} style={{ marginTop:20,overflow:"hidden" }}><div style={{ overflowX:"auto" }}><table style={{ width:"100%",borderCollapse:"collapse",minWidth:760 }}><thead><tr style={{ background:"#F8F9FC" }}>{["Invoice","Order","Issued","Total","Payment","Document"].map(h=><th key={h} style={{ textAlign:"left",padding:13,fontSize:11,color:C.muted }}>{h}</th>)}</tr></thead><tbody>{invoices.map(invoice=><tr key={invoice.id} style={{ borderTop:`1px solid ${C.border}` }}><td style={{ padding:13,fontSize:12,fontWeight:700,color:C.ink }}>{invoice.id}</td><td style={{ padding:13,fontSize:12,color:C.ink }}>{invoice.order}</td><td style={{ padding:13,fontSize:12,color:C.ink }}>{invoice.issued}</td><td style={{ padding:13,fontSize:12,color:C.ink }}>{invoice.total}</td><td style={{ padding:13,fontSize:12,fontWeight:500,color:invoice.payment==="Paid"?C.green:C.orange }}>{invoice.payment}</td><td style={{ padding:13 }}><div style={{ display:"flex",gap:6 }}><Btn size="sm" variant="secondary" onClick={()=>openPreview(invoice)} icon={<Eye size={12}/>}>Preview</Btn><Btn size="sm" variant="ghost" icon={<ArrowDownToLine size={12}/>}>Download</Btn></div></td></tr>)}</tbody></table></div></Card>{preview&&<PrototypeDialog title={`Invoice ${preview.id}`} eyebrow="DOCUMENT PREVIEW" onClose={()=>setPreview(null)} maxWidth={620} footer={<><Btn variant="ghost" onClick={()=>setPreview(null)}>Close</Btn><Btn onClick={()=>setSent(true)} disabled={sent} icon={sent?<Check size={14}/>:<Send size={14}/>}>{sent?"Invoice sent":"Send invoice"}</Btn></>}><div style={{ display:"flex",flexDirection:"column",gap:16 }}><div style={{ display:"flex",justifyContent:"space-between",alignItems:"flex-start",gap:15 }}><div><p style={{ fontSize:19,fontWeight:900,color:C.ink }}>Hivorr Seller</p><p style={{ fontSize:10,color:C.muted,marginTop:4 }}>Invoice issued to {preview.customer}</p></div><Pill label={preview.payment.toUpperCase()} color={preview.payment==="Paid"?C.green:C.orange} bg={preview.payment==="Paid"?C.greenLight:C.orangeLight}/></div><div style={{ display:"grid",gridTemplateColumns:"repeat(2,1fr)",gap:10,background:"#F8F9FC",borderRadius:13,padding:13 }}><div><p style={{ fontSize:9,color:C.muted }}>ORDER</p><p style={{ fontSize:12,fontWeight:700,marginTop:3 }}>{preview.order}</p></div><div><p style={{ fontSize:9,color:C.muted }}>ISSUED</p><p style={{ fontSize:12,fontWeight:700,marginTop:3 }}>{preview.issued}</p></div></div><div><div style={{ display:"flex",justifyContent:"space-between",padding:"11px 0",borderBottom:`1px solid ${C.border}` }}><span style={{ fontSize:12,color:C.gray }}>{preview.item}</span><strong style={{ fontSize:12 }}>{preview.subtotal}</strong></div><div style={{ display:"flex",justifyContent:"space-between",padding:"11px 0",borderBottom:`1px solid ${C.border}` }}><span style={{ fontSize:12,color:C.gray }}>Delivery</span><strong style={{ fontSize:12 }}>{preview.delivery}</strong></div><div style={{ display:"flex",justifyContent:"space-between",paddingTop:13 }}><strong style={{ fontSize:14 }}>Total</strong><strong style={{ fontSize:16,color:C.primary }}>{preview.total}</strong></div></div>{sent&&<div style={{ background:C.greenLight,borderRadius:12,padding:12,display:"flex",gap:8 }}><CheckCircle size={16} color={C.green}/><p style={{ fontSize:11,color:C.green,lineHeight:1.45 }}>Prototype sent confirmation shown. No email or live invoice was delivered.</p></div>}<p style={{ fontSize:10,color:C.muted }}>Document preview only. Payment status is shown independently from document delivery.</p></div></PrototypeDialog>}</main>;
}

function SellerAnalytics({ goTo, bp }: { goTo:(s:Screen)=>void; bp:BP }) {
  const monthRevenue=284000, monthCost=176000, grossProfit=108000;
  return <main style={{ maxWidth:1120,margin:"0 auto",padding:bp.isMobile?"22px 16px 90px":"30px 32px" }}><div style={{ display:"flex",justifyContent:"space-between",alignItems:"flex-end",gap:12,flexWrap:"wrap" }}><div><h1 style={{ fontFamily:"'Plus Jakarta Sans',sans-serif",fontSize:26,fontWeight:800,color:C.ink }}>Sales analytics</h1><p style={{ fontSize:13,color:C.gray,marginTop:4 }}>Consistent illustrative figures for July.</p></div><Btn size="sm" variant="secondary" icon={<ArrowDownToLine size={12}/>}>Export report</Btn></div><div style={{ display:"grid",gridTemplateColumns:bp.isMobile?"repeat(2,1fr)":"repeat(4,1fr)",gap:12,marginTop:20 }}>{[["Monthly revenue",`₦${(monthRevenue/1000).toFixed(0)}k`],["Acquisition cost",`₦${(monthCost/1000).toFixed(0)}k`],["Est. gross profit",`₦${(grossProfit/1000).toFixed(0)}k`],["Orders","54"]].map(([l,v],i)=><StatCard key={l} label={l} value={v} sub={i===2?"before other expenses":i===0?"+18% vs June":undefined} icon={<BarChart2 size={18} color={[C.primary,C.orange,C.green,C.purple][i]}/>} color={[C.primary,C.orange,C.green,C.purple][i]} bg={[C.primaryLight,C.orangeLight,C.greenLight,C.purpleLight][i]}/>)}</div><div style={{ display:"grid",gridTemplateColumns:bp.isDesktop?"1.2fr .8fr":"1fr",gap:18,marginTop:18 }}><Card><h2 style={{ fontSize:15,fontWeight:800,color:C.ink }}>Weekly sales</h2><div style={{ height:190,display:"flex",alignItems:"flex-end",gap:12,marginTop:18 }}>{[38,62,48,82,70,94,76].map((h,i)=><div key={i} style={{ flex:1,textAlign:"center" }}><div style={{ height:h*1.5,background:i===5?C.primary:C.primaryLight,borderRadius:"7px 7px 2px 2px" }}/><span style={{ fontSize:9,color:C.muted }}>{["M","T","W","T","F","S","S"][i]}</span></div>)}</div></Card><Card><h2 style={{ fontSize:15,fontWeight:800,color:C.ink }}>Product performance</h2>{sellerProductRows.map((p,i)=><div key={p.sku} style={{ padding:"11px 0",borderTop:i?`1px solid ${C.border}`:"none" }}><div style={{ display:"flex",justifyContent:"space-between" }}><span style={{ fontSize:11,fontWeight:700,color:C.ink }}>{p.name}</span><span style={{ fontSize:11,color:C.green,fontWeight:700 }}>₦{((p.price-p.cost)*p.sold).toLocaleString()}</span></div><p style={{ fontSize:10,color:C.muted,marginTop:3 }}>{p.sold} units · estimated gross profit</p></div>)}<button onClick={()=>goTo("seller-invoices")} style={{ color:C.primary,fontSize:11,fontWeight:700,marginTop:10 }}>View invoices →</button></Card></div></main>;
}

function SellerListing({ goTo, bp, categories }: { goTo: (s: Screen) => void; bp: BP; categories: SellerCategory[] }) {
  const [step, setStep] = useState(1);
  const activeCategories=categories.filter(category=>category.active).sort((a,b)=>a.order-b.order);
  const defaultCategory=activeCategories.find(category=>category.id==="fashion") ?? activeCategories[0];
  const [categoryId,setCategoryId]=useState(defaultCategory?.id ?? "");
  const [subcategoryId,setSubcategoryId]=useState(defaultCategory?.subcategories.find(subcategory=>subcategory.active)?.id ?? "");
  const categoryName=activeCategories.find(category=>category.id===categoryId)?.name ?? "No category selected";
  return <main style={{ maxWidth: 880, margin: "0 auto", padding: bp.isMobile ? "20px 16px 90px" : "32px" }}><button onClick={() => goTo("seller-home")} style={{ display: "flex", alignItems: "center", gap: 6, fontSize: 12, color: C.gray }}><ArrowLeft size={15} /> Seller workspace</button><div style={{ marginTop: 14 }}><Pill label="DRAFT · AUTO-SAVED" color={C.gray} bg="#E9ECF3" /><h1 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontSize: 26, fontWeight: 800, color: C.ink, marginTop: 10 }}>Create a product listing</h1><p style={{ fontSize: 13, color: C.gray, marginTop: 4 }}>Listings are reviewed before they appear in Local Market.</p></div><div style={{ display: "flex", gap: 6, marginTop: 20 }}>{["Basics", "Details", "Delivery", "Review"].map((label, i) => <button key={label} onClick={() => setStep(i + 1)} style={{ flex: 1, textAlign: "left" }}><div style={{ height: 5, background: step >= i + 1 ? C.primary : "#DDE1EB", borderRadius: 5 }} /><span style={{ display: bp.isMobile ? "none" : "block", fontSize: 10, color: step === i + 1 ? C.primary : C.muted, fontWeight: 700, marginTop: 6 }}>{i + 1}. {label}</span></button>)}</div><Card padding={bp.isMobile ? 18 : 26}><div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: 20 }}><div><p style={{ fontSize: 11, fontWeight: 800, color: C.primary }}>STEP {step} OF 4</p><h2 style={{ fontSize: 18, fontWeight: 800, color: C.ink, marginTop: 4 }}>{["Product basics", "Product details", "Delivery & fulfilment", "Review listing"][step - 1]}</h2></div><div style={{ width: 44, height: 44, borderRadius: 14, background: C.primaryLight, display: "flex", alignItems: "center", justifyContent: "center" }}>{step === 1 ? <Image size={20} color={C.primary} /> : step === 2 ? <ClipboardList size={20} color={C.primary} /> : step === 3 ? <Truck size={20} color={C.primary} /> : <Eye size={20} color={C.primary} />}</div></div>{step === 1 && <div style={{ display: "flex", flexDirection: "column", gap: 14 }}><div style={{ border: `1.5px dashed #C9CFE0`, borderRadius: 16, padding: 28, textAlign: "center", background: "#FAFBFD" }}><Upload size={25} color={C.primary} /><p style={{ fontSize: 13, fontWeight: 700, color: C.ink, marginTop: 8 }}>Add up to 8 product images</p><p style={{ fontSize: 11, color: C.muted, marginTop: 4 }}>JPG or PNG · First image becomes the cover</p></div><Input label="Product title" placeholder="e.g. Handwoven Market Tote" /><ProductTaxonomyFields categories={categories} categoryId={categoryId} subcategoryId={subcategoryId} onCategoryChange={setCategoryId} onSubcategoryChange={setSubcategoryId} isMobile={bp.isMobile}/><p style={{ fontSize:10,color:C.muted,lineHeight:1.5 }}>Categories are controlled by Hivorr administrators. Sellers cannot add or rename them.</p></div>}{step === 2 && <div style={{ display: "flex", flexDirection: "column", gap: 14 }}><Input label="Description" rows={5} placeholder="Describe materials, size, care and what makes the product special." /><div style={{ display: "grid", gridTemplateColumns: bp.isMobile ? "1fr" : "1fr 1fr", gap: 12 }}><Input label="Selling price" defaultValue="₦18,500" /><Input label="Unit acquisition cost (private)" defaultValue="₦10,500" /><Input label="Quantity" defaultValue="12" /></div><Input label="Variations" placeholder="Natural, Indigo, Terracotta" /><Input label="Condition" defaultValue="New" /></div>}{step === 3 && <div style={{ display: "flex", flexDirection: "column", gap: 14 }}><Input label="Item location" defaultValue="Lekki, Lagos" />{["Local courier delivery", "Buyer pickup", "Nationwide shipping"].map((item, i) => <div key={item} style={{ padding: 14, borderRadius: 13, background: i === 0 ? C.primaryLight : "#F8F9FC", border: `1px solid ${i === 0 ? C.primary : C.border}`, display: "flex", alignItems: "center", gap: 10 }}><CheckCircle size={18} color={i === 0 ? C.primary : C.muted} /><span style={{ fontSize: 13, fontWeight: 700, color: C.ink }}>{item}</span></div>)}</div>}{step === 4 && <div><div style={{ display: "flex", gap: 15 }}><img src={products[0].image} alt="" style={{ width: 112, height: 112, borderRadius: 15, objectFit: "cover" }} /><div><Pill label="READY FOR REVIEW" color={C.green} bg={C.greenLight} /><h3 style={{ fontSize: 17, fontWeight: 800, color: C.ink, marginTop: 9 }}>Handwoven Market Tote</h3><p style={{ fontSize: 17, color: C.primary, fontWeight: 800, marginTop: 5 }}>₦18,500</p><p style={{ fontSize: 11, color: C.muted, marginTop: 5 }}>{categoryName} · 12 available</p></div></div><div style={{ background: C.orangeLight, borderRadius: 13, padding: 13, display: "flex", gap: 9, marginTop: 18 }}><Clock size={17} color={C.orange} /><p style={{ fontSize: 11, lineHeight: 1.5, color: C.gray }}>After submission, this listing will be marked <strong>Pending review</strong>. It will not appear in Local Market until approved.</p></div></div>}<div style={{ display: "flex", justifyContent: "space-between", marginTop: 24, paddingTop: 18, borderTop: `1px solid ${C.border}` }}><Btn variant="ghost" onClick={() => setStep(Math.max(1, step - 1))}>Back</Btn>{step < 4 ? <Btn onClick={() => setStep(step + 1)} disabled={step===1&&!categoryId}>Continue</Btn> : <Btn onClick={() => goTo("seller-home")} icon={<Check size={14} />}>Submit for review</Btn>}</div></Card></main>;
}

function ErrandHome({ goTo, bp }: { goTo:(s:Screen)=>void; bp:BP }) {
  const [supportOpen,setSupportOpen]=useState(false);
  return <main style={{ maxWidth:1100,margin:"0 auto",padding:bp.isMobile?"22px 16px 90px":"30px 32px" }}><ActivityHero bp={bp} eyebrow="SEND AN ERRAND" name="Amara Diallo" description="Get everyday tasks handled by eligible providers, with clear updates from request to delivery." image={activityHeroImages.errands} imageAlt="Everyday assistant standing outside a local store with a phone" gradient="linear-gradient(125deg,#B9380A 0%,#EA580C 55%,#FB7B32 100%)" action={<Btn onClick={()=>goTo("errand-request")} icon={<Plus size={14}/>}>Create New Errand</Btn>} /><div style={{ display:"grid",gridTemplateColumns:bp.isMobile?"repeat(2,1fr)":"repeat(4,1fr)",gap:12,marginTop:18 }}>{[["Awaiting acceptance","1"],["Accepted","1"],["In progress","0"],["Completed","8"]].map(([l,v],i)=><StatCard key={l} label={l} value={v} icon={[<Clock size={18} color={C.orange}/>,<CheckCircle size={18} color={C.primary}/>,<Truck size={18} color={C.purple}/>,<Award size={18} color={C.green}/>][i]} color={[C.orange,C.primary,C.purple,C.green][i]} bg={[C.orangeLight,C.primaryLight,C.purpleLight,C.greenLight][i]}/>)}</div><div style={{ display:"grid",gridTemplateColumns:bp.isDesktop?"1.25fr .75fr":"1fr",gap:18,marginTop:18 }}><Card><div style={{ display:"flex",justifyContent:"space-between" }}><h2 style={{ fontSize:16,fontWeight:800,color:C.ink }}>Active errands</h2><button onClick={()=>goTo("errand-history")} style={{ color:C.primary,fontSize:11,fontWeight:700 }}>View all</button></div><div style={{ display:"flex",gap:12,paddingTop:16 }}><div style={{ width:42,height:42,borderRadius:12,background:C.orangeLight,display:"flex",alignItems:"center",justifyContent:"center" }}><Navigation size={18} color={C.orange}/></div><div style={{ flex:1 }}><p style={{ fontSize:13,fontWeight:800,color:C.ink }}>Prescription collection</p><p style={{ fontSize:11,color:C.muted,marginTop:3 }}>#ER-1042 · Lekki to Victoria Island</p></div><Pill label="Awaiting acceptance" color={C.orange} bg={C.orangeLight}/><Btn size="sm" variant="ghost" onClick={()=>goTo("errand-tracking")}>Track</Btn></div></Card><Card><h2 style={{ fontSize:15,fontWeight:800,color:C.ink }}>Need help?</h2><p style={{ fontSize:11,color:C.gray,lineHeight:1.55,marginTop:8 }}>Report an issue, review cancellation rules, or contact Hivorr support.</p><div style={{ marginTop:12 }}><Btn size="sm" variant="secondary" onClick={()=>setSupportOpen(true)} icon={<MessageCircle size={12}/>}>Support</Btn></div></Card></div>{supportOpen&&<PrototypeDialog title="Hivorr support" eyebrow="ERRAND ASSISTANCE" onClose={()=>setSupportOpen(false)} footer={<><Btn variant="ghost" onClick={()=>setSupportOpen(false)}>Close</Btn><Btn onClick={()=>setSupportOpen(false)} icon={<Send size={14}/>}>Send message</Btn></>}><div style={{ display:"flex",flexDirection:"column",gap:14 }}><div style={{ background:C.orangeLight,borderRadius:14,padding:14,display:"flex",gap:10 }}><MessageCircle size={19} color={C.orange}/><div><p style={{ fontSize:13,fontWeight:800,color:C.ink }}>How can we help?</p><p style={{ fontSize:11,color:C.gray,lineHeight:1.5,marginTop:3 }}>Ask about an active errand, cancellation, payment, or provider matching.</p></div></div><Input label="Request reference" defaultValue="#ER-1042"/><Input label="Message" rows={4} placeholder="Describe the assistance you need"/><p style={{ fontSize:10,color:C.muted,lineHeight:1.5 }}>Prototype only. This form does not contact a live support team.</p></div></PrototypeDialog>}</main>;
}

function ErrandHistory({ goTo, bp }: { goTo:(s:Screen)=>void; bp:BP }) {
  const rows=[["#ER-1042","Prescription collection","Awaiting acceptance",C.orange,C.orangeLight],["#ER-1018","Document delivery","Completed",C.green,C.greenLight],["#ER-0994","Collect tailor order","Completed",C.green,C.greenLight],["#ER-0967","Grocery pickup","Cancelled",C.red,C.redLight]];
  return <main style={{ maxWidth:1000,margin:"0 auto",padding:bp.isMobile?"22px 16px 90px":"30px 32px" }}><div style={{ display:"flex",justifyContent:"space-between",alignItems:"center",gap:12,flexWrap:"wrap" }}><div><h1 style={{ fontFamily:"'Plus Jakarta Sans',sans-serif",fontSize:26,fontWeight:800,color:C.ink }}>My errands</h1><p style={{ fontSize:13,color:C.gray,marginTop:4 }}>Active, completed, and cancelled requests.</p></div><Btn onClick={()=>goTo("errand-request")} icon={<Plus size={13}/>}>New Errand</Btn></div><Card style={{ marginTop:20 }}>{rows.map((r,i)=><button key={r[0]} onClick={()=>r[0]==="#ER-1042"&&goTo("errand-tracking")} style={{ width:"100%",display:"flex",alignItems:"center",gap:12,padding:"14px 0",borderTop:i?`1px solid ${C.border}`:"none",textAlign:"left",flexWrap:bp.isMobile?"wrap":"nowrap" }}><div style={{ width:40,height:40,borderRadius:11,background:C.orangeLight,display:"flex",alignItems:"center",justifyContent:"center",flexShrink:0 }}><Navigation size={17} color={C.orange}/></div><div style={{ flex:1,minWidth:bp.isMobile?170:0 }}><p style={{ fontSize:13,fontWeight:700,color:C.ink }}>{r[1]}</p><p style={{ fontSize:11,color:C.muted,marginTop:3 }}>{r[0]} · Jul {15-i*2}</p></div><Pill label={r[2] as string} color={r[3] as string} bg={r[4] as string}/><ChevronRight size={15} color={C.muted}/></button>)}</Card></main>;
}

function ErrandReview({ goTo, bp }: { goTo:(s:Screen)=>void; bp:BP }) {
  return <main style={{ maxWidth:850,margin:"0 auto",padding:bp.isMobile?"22px 16px 90px":"32px" }}><button onClick={()=>goTo("errand-request")} style={{ display:"flex",gap:6,alignItems:"center",fontSize:12,color:C.gray }}><ArrowLeft size={14}/> Edit request</button><div style={{ marginTop:16 }}><Pill label="REVIEW BEFORE SUBMISSION" color={C.orange} bg={C.orangeLight}/><h1 style={{ fontFamily:"'Plus Jakarta Sans',sans-serif",fontSize:27,fontWeight:800,color:C.ink,marginTop:10 }}>Review your errand</h1></div><div style={{ display:"grid",gridTemplateColumns:bp.isDesktop?"1.2fr .8fr":"1fr",gap:18,marginTop:20 }}><Card><h2 style={{ fontSize:16,fontWeight:800,color:C.ink }}>Prescription collection</h2><p style={{ fontSize:12,color:C.gray,lineHeight:1.6,marginTop:8 }}>Collect a prepared prescription using reference RX-1844. Call the pharmacy contact on arrival.</p><div style={{ display:"flex",gap:10,marginTop:16 }}><div><MapPin size={15} color={C.green}/><div style={{ height:36,width:2,background:"#DDE1EB",margin:"3px auto" }}/><MapPin size={15} color={C.red}/></div><div><p style={{ fontSize:12,fontWeight:700 }}>MedPlus Pharmacy, Lekki Phase 1</p><p style={{ fontSize:12,fontWeight:700,marginTop:37 }}>14 Admiralty Way, Victoria Island</p></div></div><div style={{ borderTop:`1px solid ${C.border}`,marginTop:18,paddingTop:14 }}><p style={{ fontSize:11,color:C.muted }}>Preferred pickup</p><p style={{ fontSize:12,fontWeight:700,color:C.ink,marginTop:3 }}>Today, 2:00 PM</p></div></Card><Card><h2 style={{ fontSize:15,fontWeight:800,color:C.ink }}>Estimated charges</h2>{[["Provider payout","₦3,100"],["Hivorr service charge","₦500"],["Estimated total","₦3,600"]].map(([l,v])=><div key={l} style={{ display:"flex",justifyContent:"space-between",marginTop:13,fontSize:12,fontWeight:l==="Estimated total"?800:500,color:l==="Estimated total"?C.ink:C.gray }}><span>{l}</span><span>{v}</span></div>)}<div style={{ background:C.primaryLight,borderRadius:12,padding:12,marginTop:16 }}><p style={{ fontSize:11,fontWeight:700,color:C.primary }}>Hivorr Wallet · simulated</p></div><div style={{ marginTop:16 }}><Btn size="lg" onClick={()=>goTo("errand-tracking")} icon={<Send size={14}/>}>Submit Request</Btn></div><p style={{ fontSize:10,color:C.muted,lineHeight:1.5,textAlign:"center",marginTop:8 }}>Submission creates a pending request; it does not assign a provider.</p></Card></div></main>;
}

function ErrandRequest({ goTo, bp }: { goTo: (s: Screen) => void; bp: BP }) {
  return (
    <main style={{ maxWidth: 920, margin: "0 auto", padding: bp.isMobile ? "22px 16px 90px" : "34px 32px" }}>
      <div>
        <Pill label="REQUESTER EXPERIENCE" color={C.orange} bg={C.orangeLight} />
        <h1 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 27, color: C.ink, marginTop: 10 }}>Send an Errand</h1>
        <p style={{ fontSize: 13, lineHeight: 1.6, color: C.gray, marginTop: 5 }}>Tell an eligible logistics provider what needs to be collected and where it should go.</p>
      </div>
      <div style={{ display: "grid", gridTemplateColumns: bp.isDesktop ? "1.35fr .65fr" : "1fr", gap: 18, marginTop: 22 }}>
        <Card padding={bp.isMobile ? 18 : 24}>
          <h2 style={{ fontSize: 16, fontWeight: 800, color: C.ink }}>Errand details</h2>
          <div style={{ display: "flex", flexDirection: "column", gap: 14, marginTop: 18 }}>
            <Input label="Errand title" defaultValue="Prescription collection" />
            <Input label="Detailed instructions" placeholder="e.g. Collect a prescription and deliver it to me" rows={3} />
            <div style={{ display: "grid", gridTemplateColumns: bp.isMobile ? "1fr" : "1fr 1fr", gap: 12 }}>
              <Input label="Pickup location" defaultValue="MedPlus Pharmacy, Lekki Phase 1" />
              <Input label="Destination" defaultValue="14 Admiralty Way, Victoria Island" />
            </div>
            <Input label="Instructions" placeholder="Contact person, collection reference, preferred time, or handling notes" rows={3} />
            <div style={{ display: "grid", gridTemplateColumns: bp.isMobile ? "1fr" : "1fr 1fr", gap: 12 }}>
              <Input label="Contact phone" defaultValue="+234 800 000 0000" />
              <Input label="Preferred pickup time" defaultValue="Today, 2:00 PM" />
            </div>
          </div>
          <div style={{ display: "flex", justifyContent: "flex-end", marginTop: 22, paddingTop: 18, borderTop: `1px solid ${C.border}` }}>
            <Btn onClick={() => goTo("errand-review")} icon={<ChevronRight size={14} />}>Review Request</Btn>
          </div>
        </Card>
        <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
          <Card>
            <div style={{ width: 44, height: 44, borderRadius: 14, background: C.orangeLight, display: "flex", alignItems: "center", justifyContent: "center" }}><Truck size={20} color={C.orange} /></div>
            <h3 style={{ fontSize: 14, fontWeight: 800, color: C.ink, marginTop: 12 }}>How matching works</h3>
            <p style={{ fontSize: 12, color: C.gray, lineHeight: 1.6, marginTop: 6 }}>After submission, your request becomes visible to eligible logistics providers. It remains pending until a provider accepts it.</p>
          </Card>
          <div style={{ background: C.primaryLight, borderRadius: 16, padding: 16, display: "flex", gap: 10 }}>
            <Shield size={18} color={C.primary} />
            <p style={{ fontSize: 11, color: C.gray, lineHeight: 1.55 }}>Identity and eligibility checks apply before restricted errand actions can be completed.</p>
          </div>
        </div>
      </div>
    </main>
  );
}

function ErrandTracking({ goTo, bp }: { goTo: (s: Screen) => void; bp: BP }) {
  const steps = [
    { title: "Request submitted", sub: "Today, 10:42", done: true },
    { title: "Waiting for an eligible provider", sub: "Your request is visible in the logistics request queue", active: true },
    { title: "Provider assigned", sub: "Pending provider acceptance" },
    { title: "Pickup and delivery", sub: "Not started" },
  ];
  return (
    <main style={{ maxWidth: 900, margin: "0 auto", padding: bp.isMobile ? "22px 16px 90px" : "34px 32px" }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", gap: 16 }}>
        <div><Pill label="PENDING MATCH" color={C.orange} bg={C.orangeLight} /><h1 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 27, color: C.ink, marginTop: 10 }}>Track your errand</h1><p style={{ fontSize: 13, color: C.gray, marginTop: 4 }}>Request #ER-1042</p></div>
        <Btn size="sm" variant="secondary" onClick={() => goTo("errand-request")} icon={<Plus size={13} />}>New errand</Btn>
      </div>
      <div style={{ display: "grid", gridTemplateColumns: bp.isDesktop ? "1.1fr .9fr" : "1fr", gap: 18, marginTop: 22 }}>
        <Card>
          <h2 style={{ fontSize: 16, fontWeight: 800, color: C.ink }}>Request status</h2>
          <div style={{ marginTop: 20 }}>{steps.map((step, i) => <div key={step.title} style={{ display: "flex", gap: 12, minHeight: 68 }}><div style={{ display: "flex", flexDirection: "column", alignItems: "center" }}><div style={{ width: 26, height: 26, borderRadius: "50%", background: step.done ? C.green : step.active ? C.orange : "#E5E7EB", display: "flex", alignItems: "center", justifyContent: "center" }}>{step.done ? <Check size={13} color="#fff" /> : step.active ? <Clock size={13} color="#fff" /> : <span style={{ width: 6, height: 6, borderRadius: "50%", background: C.muted }} />}</div>{i < steps.length - 1 && <div style={{ width: 2, flex: 1, background: step.done ? C.green : "#E5E7EB" }} />}</div><div><p style={{ fontSize: 13, fontWeight: 700, color: step.done || step.active ? C.ink : C.muted }}>{step.title}</p><p style={{ fontSize: 11, color: C.muted, lineHeight: 1.45, marginTop: 3 }}>{step.sub}</p></div></div>)}</div>
        </Card>
        <div style={{ display: "flex", flexDirection: "column", gap: 14 }}>
          <Card><h2 style={{ fontSize: 15, fontWeight: 800, color: C.ink }}>Prescription collection</h2><div style={{ display: "flex", gap: 10, marginTop: 14 }}><div style={{ display: "flex", flexDirection: "column", alignItems: "center" }}><div style={{ width: 10, height: 10, borderRadius: "50%", background: C.green }} /><div style={{ height: 34, width: 2, background: "#DDE1EB" }} /><MapPin size={14} color={C.red} /></div><div><p style={{ fontSize: 12, fontWeight: 700, color: C.ink }}>MedPlus Pharmacy, Lekki Phase 1</p><p style={{ fontSize: 12, color: C.gray, marginTop: 28 }}>14 Admiralty Way, Victoria Island</p></div></div></Card>
          <div style={{ background: C.orangeLight, borderRadius: 16, padding: 16, display: "flex", gap: 10 }}><AlertCircle size={18} color={C.orange} /><p style={{ fontSize: 11, color: C.gray, lineHeight: 1.55 }}>No provider has accepted this request yet. Submission does not automatically assign or complete the errand.</p></div>
        </div>
      </div>
    </main>
  );
}

function LogisticsHome({ bp }: { bp: BP }) {
  const jobs = [{ from: "MedPlus Pharmacy, Lekki", to: "14 Admiralty Way, VI", item: "Errand #ER-1042 · Prescription collection", fee: "₦3,600", distance: "7.8 km" }, { from: "Lekki Phase 1", to: "Victoria Island", item: "1 parcel · Fashion", fee: "₦3,200", distance: "8.4 km" }, { from: "Yaba", to: "Ikeja GRA", item: "2 boxes · Groceries", fee: "₦4,800", distance: "13.1 km" }];
  return <main style={{ maxWidth: 1120, margin: "0 auto", padding: bp.isMobile ? "22px 16px 90px" : "30px 32px" }}><ActivityHero bp={bp} eyebrow="I WANT TO PROVIDE LOGISTICS" name="Kemi Adisa" description="You’re online in Lagos with car coverage across 30 km. Find nearby requests and keep every delivery moving." image={activityHeroImages.logistics} imageAlt="Delivery provider carrying a package on a city street" gradient="linear-gradient(125deg,#0F5F5A 0%,#0F766E 52%,#16A34A 100%)" /><div style={{ display: "grid", gridTemplateColumns: bp.isMobile ? "repeat(2,1fr)" : "repeat(4,1fr)", gap: 12, marginTop: 18 }}>{[{ l: "Available requests", v: "12" }, { l: "Active delivery", v: "1" }, { l: "Today’s earnings", v: "₦2.8k" }, { l: "Rating", v: "4.9" }].map((item, i) => <StatCard key={item.l} label={item.l} value={item.v} icon={[<Navigation size={18} color={C.primary} />, <Truck size={18} color={C.orange} />, <Wallet size={18} color={C.green} />, <Star size={18} color={C.purple} />][i]} color={[C.primary, C.orange, C.green, C.purple][i]} bg={[C.primaryLight, C.orangeLight, C.greenLight, C.purpleLight][i]} />)}</div><div style={{ display: "grid", gridTemplateColumns: bp.isDesktop ? ".85fr 1.15fr" : "1fr", gap: 18, marginTop: 18 }}><Card style={{ border: `1.5px solid ${C.orange}35`, boxShadow: "0 14px 34px rgba(249,115,22,.13)", background: "linear-gradient(180deg,#FFFFFF 0%,#FFFCF8 100%)" }}><div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-start", gap: 10, flexWrap: "wrap" }}><div><Pill label="PRIORITY ASSIGNMENT" color={C.orange} bg={C.orangeLight} /><h2 style={{ fontSize: 17, fontWeight: 800, color: C.ink, marginTop: 8 }}>Active delivery</h2></div><Pill label="IN PROGRESS" color={C.green} bg={C.greenLight} /></div><div style={{ background: C.orangeLight, borderRadius: 13, padding: 13, marginTop: 13 }}><Pill label="PICKUP CONFIRMED" color={C.orange} bg="#fff" /><p style={{ fontSize: 14, fontWeight: 800, color: C.ink, marginTop: 9 }}>#DL-8392 · Zuri Craft House</p><p style={{ fontSize: 11, color: C.gray, marginTop: 4 }}>Deliver to Amara · Victoria Island</p></div><div style={{ marginTop: 14 }}><Btn icon={<Navigation size={14} />}>Open directions</Btn></div><div style={{ display: "flex", gap: 8, marginTop: 9 }}><Btn size="sm" variant="secondary" icon={<Phone size={12} />}>Call</Btn><Btn size="sm" variant="ghost" icon={<MessageCircle size={12} />}>Message</Btn></div></Card><Card style={{ boxShadow: "0 2px 10px rgba(15,22,38,.04)" }}><div style={{ display: "flex", justifyContent: "space-between", gap: 10, flexWrap: "wrap" }}><h2 style={{ fontSize: 15, fontWeight: 800, color: C.ink }}>Nearby delivery requests</h2><Pill label="12 LIVE" color={C.green} bg={C.greenLight} /></div>{jobs.map((job, i) => <div key={job.from} style={{ paddingTop: 16, marginTop: 16, borderTop: i ? `1px solid ${C.border}` : "none" }}><div style={{ display: "flex", gap: 12 }}><div style={{ display: "flex", flexDirection: "column", alignItems: "center" }}><div style={{ width: 10, height: 10, borderRadius: "50%", background: C.green }} /><div style={{ width: 2, height: 28, background: "#DDE1EB" }} /><MapPin size={13} color={C.red} /></div><div style={{ flex: 1 }}><p style={{ fontSize: 12, fontWeight: 700, color: C.ink }}>{job.from}</p><p style={{ fontSize: 11, color: C.muted, marginTop: 22 }}>{job.to}</p></div><div style={{ textAlign: "right" }}><p style={{ fontSize: 15, fontWeight: 800, color: C.green }}>{job.fee}</p><p style={{ fontSize: 10, color: C.muted }}>{job.distance}</p></div></div><div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginTop: 12 }}><span style={{ fontSize: 11, color: C.gray }}>{job.item}</span><Btn size="sm">View request</Btn></div></div>)}</Card></div></main>;
}

const logisticsRequests = [
  { id:"#ER-1042", type:"Errand", from:"MedPlus Pharmacy, Lekki", to:"Victoria Island", distance:"7.8 km", time:"28 min", payout:3100, vehicle:"Car or bike", note:"Prescription collection · Keep upright" },
  { id:"#DL-8401", type:"Product delivery", from:"Lekki Phase 1", to:"Ikoyi", distance:"8.4 km", time:"32 min", payout:2800, vehicle:"Bike or car", note:"Small fashion parcel" },
  { id:"#DL-8398", type:"Grocery delivery", from:"Yaba", to:"Ikeja GRA", distance:"13.1 km", time:"44 min", payout:4200, vehicle:"Car", note:"Two boxes · Handle with care" },
];

function LogisticsRequests({ goTo,bp }:{ goTo:(s:Screen)=>void;bp:BP }) {
  const [accepted,setAccepted]=useState<string|null>(null);
  return <main style={{ maxWidth:1120,margin:"0 auto",padding:bp.isMobile?"22px 16px 90px":"30px 32px" }}><div style={{ display:"flex",justifyContent:"space-between",alignItems:"flex-end",gap:12,flexWrap:"wrap" }}><div><h1 style={{ fontFamily:"'Plus Jakarta Sans',sans-serif",fontSize:26,fontWeight:800,color:C.ink }}>Available requests</h1><p style={{ fontSize:13,color:C.gray,marginTop:4 }}>Only requests matching your verified area and capabilities are shown.</p></div><Btn size="sm" variant="secondary" icon={<Filter size={12}/>}>Filters</Btn></div><div style={{ display:"flex",gap:8,overflowX:"auto",marginTop:16 }}>{["Nearest","Highest payout","Errands","Deliveries","Car eligible"].map((x,i)=><button key={x} style={{ padding:"8px 11px",borderRadius:18,background:i===0?C.green:C.card,color:i===0?"#fff":C.gray,border:`1px solid ${i===0?C.green:C.border}`,fontSize:11,fontWeight:700,whiteSpace:"nowrap" }}>{x}</button>)}</div><div style={{ display:"grid",gridTemplateColumns:bp.isDesktop?"repeat(2,1fr)":"1fr",gap:14,marginTop:16 }}>{logisticsRequests.map(r=><Card key={r.id}><div style={{ display:"flex",justifyContent:"space-between" }}><div><Pill label={r.type.toUpperCase()} color={r.type==="Errand"?C.orange:C.primary} bg={r.type==="Errand"?C.orangeLight:C.primaryLight}/><p style={{ fontSize:14,fontWeight:800,color:C.ink,marginTop:9 }}>{r.id}</p></div><div style={{ textAlign:"right" }}><p style={{ fontSize:17,fontWeight:800,color:C.green }}>₦{r.payout.toLocaleString()}</p><p style={{ fontSize:10,color:C.muted }}>provider payout</p></div></div><div style={{ display:"flex",gap:10,marginTop:15 }}><div><MapPin size={13} color={C.green}/><div style={{ height:25,width:2,background:"#DDE1EB",margin:"2px auto" }}/><MapPin size={13} color={C.red}/></div><div style={{ flex:1 }}><p style={{ fontSize:12,fontWeight:700,color:C.ink }}>{r.from}</p><p style={{ fontSize:12,color:C.gray,marginTop:23 }}>{r.to}</p></div></div><div style={{ display:"flex",gap:12,marginTop:13,fontSize:10,color:C.muted }}><span>{r.distance}</span><span>{r.time}</span><span>{r.vehicle}</span></div><p style={{ fontSize:11,color:C.gray,background:"#F8F9FC",padding:9,borderRadius:9,marginTop:11 }}>{r.note}</p><div style={{ display:"flex",justifyContent:"flex-end",gap:8,marginTop:13 }}><Btn size="sm" variant="ghost">Details</Btn><Btn size="sm" onClick={()=>{setAccepted(r.id);goTo("logistics-active")}}>{accepted===r.id?"Accepted":"Accept request"}</Btn></div></Card>)}</div><p style={{ fontSize:10,color:C.muted,marginTop:10 }}>Prototype acceptance is simulated and does not dispatch a real provider.</p></main>;
}

function LogisticsActive({ bp }:{ bp:BP }) {
  const [stage,setStage]=useState(1);
  const stages=["Accepted","Heading to pickup","Arrived at pickup","Item collected","In transit","Delivered"];
  return <main style={{ maxWidth:1020,margin:"0 auto",padding:bp.isMobile?"22px 16px 90px":"30px 32px" }}><div><Pill label="ACTIVE ASSIGNMENT" color={C.orange} bg={C.orangeLight}/><h1 style={{ fontFamily:"'Plus Jakarta Sans',sans-serif",fontSize:26,fontWeight:800,color:C.ink,marginTop:9 }}>Errand #ER-1042</h1><p style={{ fontSize:13,color:C.gray,marginTop:4 }}>Prescription collection · 7.8 km · Estimated payout ₦3,100</p></div><div style={{ display:"grid",gridTemplateColumns:bp.isDesktop?"1.2fr .8fr":"1fr",gap:18,marginTop:20 }}><Card><h2 style={{ fontSize:15,fontWeight:800,color:C.ink }}>Delivery progression</h2><div style={{ marginTop:18 }}>{stages.map((s,i)=><div key={s} style={{ display:"flex",gap:11,minHeight:56 }}><div style={{ display:"flex",flexDirection:"column",alignItems:"center" }}><div style={{ width:24,height:24,borderRadius:"50%",background:i<=stage?C.green:"#E5E7EB",display:"flex",alignItems:"center",justifyContent:"center" }}>{i<stage?<Check size={12} color="#fff"/>:<span style={{ width:6,height:6,borderRadius:"50%",background:i===stage?"#fff":C.muted }}/>}</div>{i<stages.length-1&&<div style={{ width:2,flex:1,background:i<stage?C.green:"#E5E7EB" }}/>}</div><div><p style={{ fontSize:12,fontWeight:700,color:i<=stage?C.ink:C.muted }}>{s}</p><p style={{ fontSize:10,color:C.muted,marginTop:3 }}>{i<stage?"Completed":i===stage?"Current status":"Pending"}</p></div></div>)}</div><div style={{ display:"flex",justifyContent:"space-between",paddingTop:14,borderTop:`1px solid ${C.border}` }}><Btn size="sm" variant="danger">Report issue</Btn><Btn size="sm" onClick={()=>setStage(Math.min(stages.length-1,stage+1))}>{stage===stages.length-1?"Completion recorded":"Update status"}</Btn></div></Card><div style={{ display:"flex",flexDirection:"column",gap:14 }}><Card><h2 style={{ fontSize:15,fontWeight:800,color:C.ink }}>Route overview</h2><div style={{ height:120,background:"linear-gradient(145deg,#E0F2FE,#EEF0FD)",borderRadius:13,marginTop:12,display:"flex",alignItems:"center",justifyContent:"center" }}><Navigation size={28} color={C.primary}/></div><p style={{ fontSize:11,color:C.muted,lineHeight:1.5,marginTop:8 }}>Prototype route preview · not live GPS.</p><div style={{ marginTop:10 }}><Btn size="sm" icon={<Navigation size={12}/>}>Open navigation</Btn></div></Card><Card><h2 style={{ fontSize:15,fontWeight:800,color:C.ink }}>Requester communication</h2><div style={{ display:"flex",gap:8,marginTop:12 }}><Btn size="sm" variant="secondary" icon={<Phone size={12}/>}>Call</Btn><Btn size="sm" variant="ghost" icon={<MessageCircle size={12}/>}>Message</Btn></div></Card></div></div></main>;
}

function LogisticsHistory({ bp }:{bp:BP}) {
  const rows=[["#DL-8388","Fashion parcel","Completed","₦2,800"],["#ER-1028","Document errand","Completed","₦3,400"],["#DL-8369","Grocery delivery","Completed","₦4,200"],["#DL-8347","Electronics parcel","Cancelled","₦0"]];
  return <main style={{ maxWidth:1000,margin:"0 auto",padding:bp.isMobile?"22px 16px 90px":"30px 32px" }}><div><h1 style={{ fontFamily:"'Plus Jakarta Sans',sans-serif",fontSize:26,fontWeight:800,color:C.ink }}>Delivery history</h1><p style={{ fontSize:13,color:C.gray,marginTop:4 }}>Completed and cancelled assignments.</p></div><Card style={{ marginTop:20 }}>{rows.map((r,i)=><div key={r[0]} style={{ display:"flex",alignItems:"center",gap:12,padding:"14px 0",borderTop:i?`1px solid ${C.border}`:"none",flexWrap:bp.isMobile?"wrap":"nowrap" }}><div style={{ width:40,height:40,borderRadius:11,background:r[2]==="Completed"?C.greenLight:C.redLight,display:"flex",alignItems:"center",justifyContent:"center",flexShrink:0 }}><Truck size={17} color={r[2]==="Completed"?C.green:C.red}/></div><div style={{ flex:1,minWidth:bp.isMobile?150:0 }}><p style={{ fontSize:13,fontWeight:700,color:C.ink }}>{r[1]}</p><p style={{ fontSize:11,color:C.muted }}>{r[0]} · Jul {14-i}</p></div><Pill label={r[2]} color={r[2]==="Completed"?C.green:C.red} bg={r[2]==="Completed"?C.greenLight:C.redLight}/><strong style={{ fontSize:12 }}>{r[3]}</strong></div>)}</Card></main>;
}

function LogisticsEarnings({ bp }:{bp:BP}) {
  return <main style={{ maxWidth:1060,margin:"0 auto",padding:bp.isMobile?"22px 16px 90px":"30px 32px" }}><div><h1 style={{ fontFamily:"'Plus Jakarta Sans',sans-serif",fontSize:26,fontWeight:800,color:C.ink }}>Earnings & payouts</h1><p style={{ fontSize:13,color:C.gray,marginTop:4 }}>Gross assignment earnings, fees, and payable balance.</p></div><div style={{ display:"grid",gridTemplateColumns:bp.isMobile?"repeat(2,1fr)":"repeat(4,1fr)",gap:12,marginTop:20 }}>{[["Today","₦18.4k"],["This week","₦72.6k"],["This month","₦248k"],["Pending payout","₦64.2k"]].map(([l,v],i)=><StatCard key={l} label={l} value={v} icon={<Wallet size={18} color={[C.green,C.primary,C.purple,C.orange][i]}/>} color={[C.green,C.primary,C.purple,C.orange][i]} bg={[C.greenLight,C.primaryLight,C.purpleLight,C.orangeLight][i]}/>)}</div><div style={{ display:"grid",gridTemplateColumns:bp.isDesktop?"1.2fr .8fr":"1fr",gap:18,marginTop:18 }}><Card><h2 style={{ fontSize:15,fontWeight:800,color:C.ink }}>Recent assignment earnings</h2>{[["#DL-8388","Gross ₦3,000 · fee ₦200","₦2,800"],["#ER-1028","Gross ₦3,650 · fee ₦250","₦3,400"],["#DL-8369","Gross ₦4,500 · fee ₦300","₦4,200"]].map((r,i)=><div key={r[0]} style={{ display:"flex",alignItems:"center",padding:"13px 0",borderTop:i?`1px solid ${C.border}`:"none" }}><div style={{ flex:1 }}><p style={{ fontSize:12,fontWeight:700,color:C.ink }}>{r[0]}</p><p style={{ fontSize:10,color:C.muted,marginTop:3 }}>{r[1]}</p></div><strong style={{ color:C.green,fontSize:13 }}>{r[2]}</strong></div>)}</Card><Card><Pill label="PENDING" color={C.orange} bg={C.orangeLight}/><h2 style={{ fontSize:15,fontWeight:800,color:C.ink,marginTop:10 }}>Next payout</h2><p style={{ fontSize:28,fontWeight:800,color:C.ink,marginTop:8 }}>₦64,200</p><p style={{ fontSize:11,color:C.gray,marginTop:4 }}>Estimated Friday · Bank ending 4182</p><p style={{ fontSize:10,color:C.muted,lineHeight:1.5,marginTop:12 }}>A pending payout is not marked completed until settlement is confirmed.</p></Card></div></main>;
}

type AnalysisPeriod = "daily" | "weekly" | "monthly";

function AnalysisPeriodTabs({ period, onChange, color }: { period: AnalysisPeriod; onChange: (period: AnalysisPeriod) => void; color: string }) {
  return <div style={{ display: "flex", gap: 4, padding: 4, borderRadius: 13, background: C.card, border: `1px solid ${C.border}` }}>
    {(["daily", "weekly", "monthly"] as const).map(option => <button key={option} onClick={() => onChange(option)} style={{ padding: "8px 12px", borderRadius: 10, background: period === option ? color : "transparent", color: period === option ? "#fff" : C.gray, fontSize: 11, fontWeight: 700, textTransform: "capitalize" }}>{option}</button>)}
  </div>;
}

function ProfessionalEarningsAnalysis({ bp }: { bp: BP }) {
  const [period, setPeriod] = useState<AnalysisPeriod>("monthly");
  const recognisedEarnings = proEarnings.filter(transaction => transaction.type === "credit");
  const pendingEarnings = proEarnings.filter(transaction => transaction.type === "escrow");
  const parseUsd = (amount: string) => Number(amount.replace(/[^0-9.-]/g, ""));
  const totalRecognised = recognisedEarnings.reduce((total, transaction) => total + parseUsd(transaction.amount), 0);
  const totalPending = pendingEarnings.reduce((total, transaction) => total + parseUsd(transaction.amount), 0);
  const periodData = {
    daily: { earnings: 3500, completed: 1, trend: [18,28,24,46,58,72,88] },
    weekly: { earnings: totalRecognised, completed: recognisedEarnings.length, trend: [32,48,42,66,74,58,92] },
    monthly: { earnings: totalRecognised, completed: recognisedEarnings.length, trend: [28,38,46,42,62,72,68,84,76,90,82,96] },
  }[period];
  const activeJobs = jobListings.filter(job => job.status === "in-progress").length;
  const averageEarnings = recognisedEarnings.length ? totalRecognised / recognisedEarnings.length : 0;
  return <main style={{ maxWidth: 1100, margin: "0 auto", padding: bp.isMobile ? "22px 16px 90px" : "30px 32px" }}>
    <div style={{ display: "flex", alignItems: "flex-end", justifyContent: "space-between", gap: 14, flexWrap: "wrap" }}><div><Pill label="PROFESSIONAL SERVICES" color={C.green} bg={C.greenLight} /><h1 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontSize: 26, fontWeight: 800, color: C.ink, marginTop: 9 }}>Earnings Analysis</h1><p style={{ fontSize: 13, color: C.gray, marginTop: 4 }}>Recognised earnings from completed, paid professional work only.</p></div><AnalysisPeriodTabs period={period} onChange={setPeriod} color={C.green} /></div>
    <div style={{ display: "grid", gridTemplateColumns: bp.isMobile ? "repeat(2,1fr)" : "repeat(4,1fr)", gap: 12, marginTop: 20 }}>
      {[["Total earnings",`$${totalRecognised.toLocaleString()}`],["Selected period",`$${periodData.earnings.toLocaleString()}`],["Completed jobs",periodData.completed.toString()],["Average per job",`$${averageEarnings.toLocaleString()}`]].map(([label,value],i)=><StatCard key={label} label={label} value={value} icon={<DollarSign size={18} color={[C.green,C.primary,C.purple,C.orange][i]}/>} color={[C.green,C.primary,C.purple,C.orange][i]} bg={[C.greenLight,C.primaryLight,C.purpleLight,C.orangeLight][i]}/>)}
    </div>
    <div style={{ display: "grid", gridTemplateColumns: bp.isDesktop ? "1.25fr .75fr" : "1fr", gap: 18, marginTop: 18 }}>
      <Card><div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}><div><h2 style={{ fontSize: 15, fontWeight: 800, color: C.ink }}>Earnings trend</h2><p style={{ fontSize: 10, color: C.muted, marginTop: 3 }}>{period} recognised payments</p></div><Pill label={period.toUpperCase()} color={C.green} bg={C.greenLight} /></div><div style={{ height: 180, display: "flex", alignItems: "flex-end", gap: 8, marginTop: 18 }}>{periodData.trend.map((height,index)=><div key={index} style={{ flex: 1, height: `${height}%`, minHeight: 12, background: index === periodData.trend.length - 1 ? C.green : C.greenLight, borderRadius: "6px 6px 2px 2px" }} />)}</div></Card>
      <div style={{ display: "flex", flexDirection: "column", gap: 14 }}><Card><h2 style={{ fontSize: 15, fontWeight: 800, color: C.ink }}>Work status</h2>{[["Active jobs",activeJobs.toString()],["Pending earnings",`$${totalPending.toLocaleString()}`],["Paid jobs",recognisedEarnings.length.toString()]].map(([label,value],i)=><div key={label} style={{ display: "flex", justifyContent: "space-between", padding: "12px 0", borderTop: i ? `1px solid ${C.border}` : "none" }}><span style={{ fontSize: 11, color: C.gray }}>{label}</span><strong style={{ fontSize: 12, color: label === "Pending earnings" ? C.orange : C.ink }}>{value}</strong></div>)}</Card><Card><h2 style={{ fontSize: 15, fontWeight: 800, color: C.ink }}>Recognised job breakdown</h2>{recognisedEarnings.map((transaction,i)=><div key={transaction.id} style={{ padding: "11px 0", borderTop: i ? `1px solid ${C.border}` : "none" }}><div style={{ display: "flex", justifyContent: "space-between", gap: 10 }}><span style={{ fontSize: 11, fontWeight: 700, color: C.ink }}>{transaction.job}</span><strong style={{ fontSize: 11, color: C.green }}>{transaction.amount.replace("+","")}</strong></div><p style={{ fontSize: 10, color: C.muted, marginTop: 3 }}>{transaction.desc}</p></div>)}</Card></div>
    </div>
    <p style={{ fontSize: 10, color: C.muted, marginTop: 10 }}>Quotations, applications, and uncompleted jobs are excluded. Pending escrow is shown separately and is not recognised as earned.</p>
  </main>;
}

function SellerSalesAnalysis({ goTo, bp }: { goTo: (screen: Screen) => void; bp: BP }) {
  const [period, setPeriod] = useState<AnalysisPeriod>("monthly");
  const totalUnitsSold = sellerProductRows.reduce((total, product) => total + product.sold, 0);
  const totalRevenue = sellerProductRows.reduce((total, product) => total + product.price * product.sold, 0);
  const totalGrossProfit = sellerProductRows.reduce((total, product) => total + (product.price - product.cost) * product.sold, 0);
  const periodData = {
    daily: { revenue: 32000, orders: 1, units: 1, grossProfit: 13000, trend: [22,34,28,46,62,74,88] },
    weekly: { revenue: 99500, orders: 3, units: 3, grossProfit: 39700, trend: [36,52,44,68,76,92,80] },
    monthly: { revenue: 284000, orders: 54, units: totalUnitsSold, grossProfit: 108000, trend: [38,62,48,82,70,94,76] },
  }[period];
  return <main style={{ maxWidth: 1120, margin: "0 auto", padding: bp.isMobile ? "22px 16px 90px" : "30px 32px" }}>
    <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-end", gap: 14, flexWrap: "wrap" }}><div><Pill label="SELLER BUSINESS PERFORMANCE" color={C.purple} bg={C.purpleLight} /><h1 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontSize: 26, fontWeight: 800, color: C.ink, marginTop: 9 }}>Sales Analysis</h1><p style={{ fontSize: 13, color: C.gray, marginTop: 4 }}>Sales revenue and product performance, separate from wallet funds.</p></div><AnalysisPeriodTabs period={period} onChange={setPeriod} color={C.purple} /></div>
    <div style={{ display: "grid", gridTemplateColumns: bp.isMobile ? "repeat(2,1fr)" : "repeat(4,1fr)", gap: 12, marginTop: 20 }}>
      {[["Total sales",`${totalUnitsSold} products`],[`${period[0].toUpperCase()}${period.slice(1)} revenue`,`₦${periodData.revenue.toLocaleString()}`],["Completed orders","46"],["Open orders","8"]].map(([label,value],i)=><StatCard key={label} label={label} value={value} icon={<BarChart2 size={18} color={[C.purple,C.green,C.primary,C.orange][i]}/>} color={[C.purple,C.green,C.primary,C.orange][i]} bg={[C.purpleLight,C.greenLight,C.primaryLight,C.orangeLight][i]}/>)}
    </div>
    <div style={{ display: "grid", gridTemplateColumns: bp.isDesktop ? "1.2fr .8fr" : "1fr", gap: 18, marginTop: 18 }}>
      <Card><div style={{ display: "flex", justifyContent: "space-between" }}><div><h2 style={{ fontSize: 15, fontWeight: 800, color: C.ink }}>Sales trend</h2><p style={{ fontSize: 10, color: C.muted, marginTop: 3 }}>{periodData.orders} orders · {periodData.units} products sold</p></div><Pill label={period.toUpperCase()} color={C.purple} bg={C.purpleLight} /></div><div style={{ height: 190, display: "flex", alignItems: "flex-end", gap: 10, marginTop: 18 }}>{periodData.trend.map((height,index)=><div key={index} style={{ flex: 1, height: `${height}%`, background: index === periodData.trend.length - 1 ? C.purple : C.purpleLight, borderRadius: "7px 7px 2px 2px" }} />)}</div></Card>
      <Card><h2 style={{ fontSize: 15, fontWeight: 800, color: C.ink }}>Revenue & profitability</h2>{[["Total revenue",`₦${totalRevenue.toLocaleString()}`],["Selected-period revenue",`₦${periodData.revenue.toLocaleString()}`],["Estimated gross profit",`₦${periodData.grossProfit.toLocaleString()}`],["All-time gross profit",`₦${totalGrossProfit.toLocaleString()}`],["Estimated net profit","Not available"]].map(([label,value],i)=><div key={label} style={{ display: "flex", justifyContent: "space-between", gap: 12, padding: "12px 0", borderTop: i ? `1px solid ${C.border}` : "none" }}><span style={{ fontSize: 11, color: C.gray }}>{label}</span><strong style={{ fontSize: 11, color: value === "Not available" ? C.muted : C.ink }}>{value}</strong></div>)}<p style={{ fontSize: 10, color: C.muted, lineHeight: 1.5 }}>Net profit cannot be substantiated because fees, taxes, returns, and operating expenses are not recorded.</p></Card>
    </div>
    <Card style={{ marginTop:18 }}><div style={{ display: "flex", justifyContent: "space-between", alignItems: "center",gap:12,flexWrap:"wrap" }}><div><h2 style={{ fontSize: 15, fontWeight: 800, color: C.ink }}>Best-selling products</h2><p style={{ fontSize: 10, color: C.muted, marginTop: 3 }}>Revenue, units sold, and supported gross profit</p></div><Btn size="sm" variant="ghost" onClick={() => goTo("seller-invoices")}>View invoices</Btn></div>{[...sellerProductRows].sort((a,b)=>b.sold-a.sold).map((product,i)=><div key={product.sku} style={{ display: "flex", alignItems: "center", gap: 11, padding: "12px 0", borderTop: i ? `1px solid ${C.border}` : "none",flexWrap:bp.isMobile?"wrap":"nowrap" }}><div style={{ width: 28, height: 28, borderRadius: 9, background: C.purpleLight, color: C.purple, display: "flex", alignItems: "center", justifyContent: "center", fontSize: 11, fontWeight: 800,flexShrink:0 }}>{i+1}</div><div style={{ flex: 1,minWidth:bp.isMobile?180:0 }}><p style={{ fontSize: 12, fontWeight: 700, color: C.ink }}>{product.name}</p><p style={{ fontSize: 10, color: C.muted, marginTop: 3 }}>{product.sold} sold · ₦{(product.price*product.sold).toLocaleString()} revenue</p></div><strong style={{ fontSize: 11, color: C.green }}>₦{((product.price-product.cost)*product.sold).toLocaleString()} gross</strong></div>)}</Card>
  </main>;
}

function LogisticsAnalysis({ bp }: { bp: BP }) {
  const [period, setPeriod] = useState<AnalysisPeriod>("monthly");
  const completedDeliveries = [{ id:"#DL-8388", amount:2800 },{ id:"#ER-1028", amount:3400 },{ id:"#DL-8369", amount:4200 }];
  const totalEarnings = completedDeliveries.reduce((total, delivery) => total + delivery.amount, 0);
  const periodData = {
    daily: { earnings: 2800, completed: 1, trend: [18,26,42,38,58,72,86] },
    weekly: { earnings: totalEarnings, completed: completedDeliveries.length, trend: [30,46,54,42,68,84,76] },
    monthly: { earnings: totalEarnings, completed: completedDeliveries.length, trend: [22,34,48,40,62,74,70,88,76,92,84,96] },
  }[period];
  const averageEarnings = totalEarnings / completedDeliveries.length;
  return <main style={{ maxWidth: 1080, margin: "0 auto", padding: bp.isMobile ? "22px 16px 90px" : "30px 32px" }}>
    <div style={{ display: "flex", justifyContent: "space-between", alignItems: "flex-end", gap: 14, flexWrap: "wrap" }}><div><Pill label="LOGISTICS PERFORMANCE" color={C.orange} bg={C.orangeLight} /><h1 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontSize: 26, fontWeight: 800, color: C.ink, marginTop: 9 }}>Analysis</h1><p style={{ fontSize: 13, color: C.gray, marginTop: 4 }}>Completed-delivery earnings and operational performance.</p></div><AnalysisPeriodTabs period={period} onChange={setPeriod} color={C.orange} /></div>
    <div style={{ display: "grid", gridTemplateColumns: bp.isMobile ? "repeat(2,1fr)" : "repeat(4,1fr)", gap: 12, marginTop: 20 }}>{[["Total delivery earnings",`₦${totalEarnings.toLocaleString()}`],["Selected period",`₦${periodData.earnings.toLocaleString()}`],["Completed deliveries",periodData.completed.toString()],["Average per delivery",`₦${Math.round(averageEarnings).toLocaleString()}`]].map(([label,value],i)=><StatCard key={label} label={label} value={value} icon={<Truck size={18} color={[C.green,C.orange,C.primary,C.purple][i]}/>} color={[C.green,C.orange,C.primary,C.purple][i]} bg={[C.greenLight,C.orangeLight,C.primaryLight,C.purpleLight][i]}/>)}</div>
    <div style={{ display: "grid", gridTemplateColumns: bp.isDesktop ? "1.2fr .8fr" : "1fr", gap: 18, marginTop: 18 }}><Card><div style={{ display: "flex", justifyContent: "space-between" }}><div><h2 style={{ fontSize: 15, fontWeight: 800, color: C.ink }}>Delivery earnings trend</h2><p style={{ fontSize: 10, color: C.muted, marginTop: 3 }}>Completed assignments only</p></div><Pill label={period.toUpperCase()} color={C.orange} bg={C.orangeLight} /></div><div style={{ height: 185, display: "flex", alignItems: "flex-end", gap: 8, marginTop: 18 }}>{periodData.trend.map((height,index)=><div key={index} style={{ flex: 1, height: `${height}%`, background: index === periodData.trend.length - 1 ? C.orange : C.orangeLight, borderRadius: "6px 6px 2px 2px" }} />)}</div></Card><Card><h2 style={{ fontSize: 15, fontWeight: 800, color: C.ink }}>Assignment performance</h2>{[["Active deliveries","1"],["Cancelled assignments","1"],["Completion rate","75%"],["Available requests","12"]].map(([label,value],i)=><div key={label} style={{ display: "flex", justifyContent: "space-between", padding: "12px 0", borderTop: i ? `1px solid ${C.border}` : "none" }}><span style={{ fontSize: 11, color: C.gray }}>{label}</span><strong style={{ fontSize: 12, color: label === "Cancelled assignments" ? C.red : C.ink }}>{value}</strong></div>)}</Card></div>
    <Card style={{ marginTop:18 }}><h2 style={{ fontSize: 15, fontWeight: 800, color: C.ink }}>Completed delivery breakdown</h2>{completedDeliveries.map((delivery,i)=><div key={delivery.id} style={{ display: "flex", alignItems: "center",gap:12, padding: "12px 0", borderTop: i ? `1px solid ${C.border}` : "none" }}><div style={{ flex: 1,minWidth:0 }}><p style={{ fontSize: 12, fontWeight: 700, color: C.ink }}>{delivery.id}</p><p style={{ fontSize: 10, color: C.muted, marginTop: 3 }}>Financially recognised completed delivery</p></div><strong style={{ fontSize: 12, color: C.green,flexShrink:0 }}>₦{delivery.amount.toLocaleString()}</strong></div>)}</Card>
    <p style={{ fontSize: 10, color: C.muted, marginTop: 10 }}>Available requests and active assignments are not counted as earnings until delivery completion is financially recognised.</p>
  </main>;
}

function LogisticsProfile({ bp }:{bp:BP}) {
  return <main style={{ maxWidth:900,margin:"0 auto",padding:bp.isMobile?"22px 16px 90px":"30px 32px" }}><div><h1 style={{ fontFamily:"'Plus Jakarta Sans',sans-serif",fontSize:26,fontWeight:800,color:C.ink }}>Provider profile</h1><p style={{ fontSize:13,color:C.gray,marginTop:4 }}>Availability, service coverage, transport, and verification.</p></div><div style={{ display:"grid",gridTemplateColumns:bp.isDesktop?".75fr 1.25fr":"1fr",gap:18,marginTop:20 }}><Card><div style={{ textAlign:"center" }}><Av initials="KA" color={C.green} size={70}/><h2 style={{ fontSize:16,fontWeight:800,color:C.ink,marginTop:10 }}>Kemi Adisa</h2><p style={{ fontSize:12,color:C.gray,marginTop:3 }}>Lagos logistics provider</p><div style={{ marginTop:10 }}><Pill label="IDENTITY VERIFIED" color={C.green} bg={C.greenLight}/></div></div></Card><Card><h2 style={{ fontSize:15,fontWeight:800,color:C.ink }}>Provider settings</h2><div style={{ display:"grid",gridTemplateColumns:bp.isMobile?"1fr":"1fr 1fr",gap:12,marginTop:14 }}><Input label="Service area" defaultValue="Lagos · 30 km radius"/><Input label="Transport" defaultValue="Car"/><Input label="Availability" defaultValue="Online"/><Input label="Contact" defaultValue="+234 800 000 0000"/></div><div style={{ background:C.orangeLight,borderRadius:12,padding:12,marginTop:14 }}><p style={{ fontSize:11,color:C.gray,lineHeight:1.5 }}>Additional document checks may apply to specific request types. No unsupported licence requirement is implied.</p></div><div style={{ marginTop:14 }}><Btn size="sm">Save settings</Btn></div></Card></div></main>;
}

function ActivitiesHub({ goTo, bp }: { goTo: (s: Screen) => void; bp: BP }) {
  const activities = [{ title: "Shop Local Market", sub: "Buy products from local sellers", icon: ShoppingBag, color: C.primary, bg: C.primaryLight, active: true, screen: "market-home" as Screen }, { title: "Hire professionals", sub: "Employer dashboard", icon: Users, color: C.primary, bg: C.primaryLight, active: true, screen: "emp-home" as Screen }, { title: "Offer services", sub: "Professional dashboard", icon: Award, color: C.green, bg: C.greenLight, active: true, screen: "pro-home" as Screen }, { title: "Sell products", sub: "Seller workspace", icon: Store, color: C.purple, bg: C.purpleLight, active: true, screen: "seller-home" as Screen }, { title: "Provide logistics", sub: "Delivery workspace", icon: Truck, color: C.orange, bg: C.orangeLight, active: false, screen: "logistics-home" as Screen }];
  return <main style={{ maxWidth: 1000, margin: "0 auto", padding: bp.isMobile ? "24px 16px 90px" : "36px 32px" }}><div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", gap:12 }}><div><Pill label="ONE HIVORR ACCOUNT" color={C.primary} bg={C.primaryLight} /><h1 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 28, color: C.ink, marginTop: 10 }}>Your activities</h1><p style={{ fontSize: 13, color: C.gray, marginTop: 5 }}>Move between what you do without switching accounts.</p></div><button onClick={() => goTo("market-home")} style={{ width: 38, height: 38, borderRadius: 11, background: C.card, display: "flex", alignItems: "center", justifyContent: "center",flexShrink:0 }}><X size={17} color={C.gray} /></button></div><div style={{ display: "grid", gridTemplateColumns: bp.isDesktop ? "repeat(2,1fr)" : "1fr", gap: 13, marginTop: 24 }}>{activities.map(activity => { const Icon = activity.icon; return <button key={activity.title} onClick={() => goTo(activity.screen)} style={{ background: C.card, borderRadius: 17, padding: 18, border: `1px solid ${C.border}`, boxShadow:"0 2px 12px rgba(15,22,38,.05)", display: "flex", alignItems: "center", gap: 13, textAlign: "left",minWidth:0 }}><div style={{ width: 46, height: 46, borderRadius: 14, background: activity.bg, display: "flex", alignItems: "center", justifyContent: "center",flexShrink:0 }}><Icon size={21} color={activity.color} /></div><div style={{ flex: 1,minWidth:0 }}><p style={{ fontSize: 14, fontWeight: 800, color: C.ink }}>{activity.title}</p><p style={{ fontSize: 11, color: C.muted, marginTop: 3 }}>{activity.sub}</p></div><Pill label={activity.active ? "Active" : "Set up"} color={activity.active ? C.green : C.orange} bg={activity.active ? C.greenLight : C.orangeLight} /><ChevronRight size={16} color={C.muted} /></button>; })}</div><Card style={{ marginTop:13 }}><div style={{ display: "flex", alignItems: "center", gap: 13 }}><div style={{ width: 46, height: 46, borderRadius: 14, background: "#F4F6FB", display: "flex", alignItems: "center", justifyContent: "center",flexShrink:0 }}><Plus size={20} color={C.primary} /></div><div><p style={{ fontSize: 14, fontWeight: 800, color: C.ink }}>More activities are coming</p><p style={{ fontSize: 11, color: C.gray, marginTop: 3 }}>Your profile, identity, messages, notifications, and wallet stay shared.</p></div></div></Card></main>;
}

type AdminRecordModule = "clients"|"jobs"|"hiring"|"applications"|"verification"|"payments"|"requests"|"monitoring"|"access"|"notifications"|"reports"|"disputes"|"support"|"security";
type AdminModuleRecord = { id:string; title:string; description:string; status:string; fields:Record<string,string> };

function getAdminModuleData(module:AdminRecordModule):{title:string;description:string;icon:LucideIcon;primaryAction:string;secondaryAction?:string;records:AdminModuleRecord[]} {
  const configs: Record<AdminRecordModule,{title:string;description:string;icon:LucideIcon;primaryAction:string;secondaryAction?:string;records:AdminModuleRecord[]}> = {
    clients:{title:"Client Management",description:"Registered client accounts, business profiles, verification and hiring activity.",icon:Users,primaryAction:"View profile",secondaryAction:"Suspend",records:[
      {id:"CL-1042",title:"TechVentures Africa",description:"Technology employer account",status:"Active",fields:{Email:"hr@techventures.ng",Phone:"+234 803 445 2180",Joined:"Mar 14, 2024",Verification:"Business verified",Jobs:"32 posted · 8 active",Payments:"$48,600 lifetime"}},
      {id:"CL-1018",title:"Lagos Properties Ltd",description:"Property management client",status:"Suspended",fields:{Email:"info@lagosprops.ng",Phone:"+234 809 114 9072",Joined:"Feb 02, 2024",Verification:"Identity verified",Jobs:"12 posted · 0 active",Payments:"$18,240 lifetime"}},
      {id:"CL-0994",title:"StartupHub GH",description:"Startup programme client",status:"Active",fields:{Email:"projects@startuphub.gh",Phone:"+233 24 881 4021",Joined:"Apr 21, 2024",Verification:"Business verified",Jobs:"18 posted · 3 active",Payments:"$25,810 lifetime"}},
    ]},
    jobs:{title:"Job Management",description:"Actual jobs posted by clients, with moderation and activity context.",icon:Briefcase,primaryAction:"View job",secondaryAction:"Reject",records:jobListings.slice(0,8).map(job=>({id:`JOB-${job.id.toString().padStart(4,"0")}`,title:job.title,description:job.desc,status:job.status==="open"?"Published":job.status==="in-progress"?"In progress":"Completed",fields:{Client:job.company,Category:job.category,Location:job.location,Budget:job.budget,"Date posted":job.posted,Applicants:String(job.applicants)}}))},
    hiring:{title:"Hiring Management",description:"Confirmed and pending hiring relationships between clients and professionals.",icon:CheckCircle,primaryAction:"View engagement",records:[
      {id:"HIRE-2041",title:"TechVentures Africa → Amara Diallo",description:"Senior React Developer",status:"Active",fields:{Client:"TechVentures Africa",Professional:"Amara Diallo",Job:"Senior React Developer","Hired on":"Jul 08, 2026","Start date":"Jul 10, 2026",Contract:"$3,500 fixed"}},
      {id:"HIRE-2032",title:"StartupHub GH → Kwame Asante",description:"Brand Identity Design Package",status:"Completed",fields:{Client:"StartupHub GH",Professional:"Kwame Asante",Job:"Brand Identity Design Package","Hired on":"Jun 20, 2026","Completed":"Jul 04, 2026",Contract:"$800 fixed"}},
      {id:"HIRE-2028",title:"Lagos Properties → Fatima Hassan",description:"Office Renovation & Electrical",status:"Pending",fields:{Client:"Lagos Properties Ltd",Professional:"Fatima Hassan",Job:"Office Renovation & Electrical","Selected on":"Jul 12, 2026","Start date":"Awaiting confirmation",Contract:"$1,200 fixed"}},
    ]},
    applications:{title:"Application Management",description:"Professional applications linked to jobs, profiles and proposed terms.",icon:FileText,primaryAction:"View application",secondaryAction:"Escalate",records:applications.map(application=>({id:`APP-${application.id.toString().padStart(4,"0")}`,title:application.pro.name,description:application.coverLetter,status:application.status.charAt(0).toUpperCase()+application.status.slice(1),fields:{Job:jobListings.find(job=>job.id===application.jobId)?.title??"Job",Professional:application.pro.role,"Proposed rate":application.proposedRate,"Applied":application.appliedDate,Rating:String(application.pro.rating),Location:application.pro.location}}))},
    verification:{title:"Verification Management",description:"Identity, business, professional credential and trade evidence reviews.",icon:Shield,primaryAction:"Review evidence",secondaryAction:"Reject",records:[
      {id:"VER-8042",title:"Chidi Okonkwo",description:"Professional identity and data qualification review",status:"Pending",fields:{"Account type":"Professional","Identity document":"National ID · submitted","Professional evidence":"Data analytics certificate","Trade evidence":"Not applicable","Submitted":"Jul 14, 2026","Reviewer":"Unassigned"}},
      {id:"VER-8038",title:"SwiftDrop Lagos",description:"Logistics provider eligibility review",status:"In review",fields:{"Account type":"Logistics provider","Identity document":"Director ID · verified","Business document":"CAC certificate","Vehicle evidence":"2 vehicles submitted","Submitted":"Jul 13, 2026","Reviewer":"M. Okafor"}},
      {id:"VER-8029",title:"Nova Gadget Store",description:"Seller business verification",status:"Approved",fields:{"Account type":"Seller","Identity document":"National ID · verified","Business document":"CAC certificate","Address evidence":"Utility bill · verified","Submitted":"Jul 10, 2026","Reviewer":"S. Mensah"}},
    ]},
    payments:{title:"Payment Management",description:"Job and marketplace transactions with payer, recipient and settlement context.",icon:Wallet,primaryAction:"View transaction",secondaryAction:"Place hold",records:[
      {id:"TXN-948201",title:"TechVentures Africa → Amara Diallo",description:"Payment for Senior React Developer",status:"Completed",fields:{Reference:"TXN-948201",Payer:"TechVentures Africa",Recipient:"Amara Diallo",Amount:"$3,500",Job:"Senior React Developer",Date:"Jul 15, 2026 · 09:14"}},
      {id:"TXN-948155",title:"Lagos Properties → Escrow",description:"Escrow funding for Office Renovation",status:"Held",fields:{Reference:"TXN-948155",Payer:"Lagos Properties Ltd",Recipient:"Escrow",Amount:"$1,200",Job:"Office Renovation & Electrical",Date:"Jul 14, 2026 · 16:42"}},
      {id:"TXN-948103",title:"Amara Diallo → Zuri Craft House",description:"Local Market purchase",status:"Authorized",fields:{Reference:"TXN-948103",Payer:"Amara Diallo",Recipient:"Zuri Craft House",Amount:"₦21,000",Order:"#HV-20481",Date:"Jul 14, 2026 · 10:42"}},
    ]},
    requests:{title:"Request Management",description:"Submitted errand and operational requests with assignment and resolution controls.",icon:Navigation,primaryAction:"View request",secondaryAction:"Resolve",records:[
      {id:"ER-1042",title:"Prescription collection",description:"Lekki Phase 1 to Victoria Island",status:"Awaiting acceptance",fields:{Requester:"Amara Diallo",Category:"Collection & delivery",Pickup:"MedPlus Pharmacy, Lekki",Destination:"Victoria Island",Submitted:"Jul 15, 2026 · 10:42",Assignment:"Unassigned"}},
      {id:"ER-1018",title:"Document delivery",description:"Ikoyi to Lagos Island",status:"In progress",fields:{Requester:"Tomi Adebayo",Category:"Document delivery",Pickup:"Ikoyi",Destination:"Lagos Island",Submitted:"Jul 13, 2026",Assignment:"Kemi Adisa"}},
      {id:"ER-0994",title:"Collect tailor order",description:"Yaba to Surulere",status:"Completed",fields:{Requester:"Lola Mensah",Category:"Collection & delivery",Pickup:"Yaba",Destination:"Surulere",Submitted:"Jul 11, 2026",Assignment:"SwiftDrop Lagos"}},
    ]},
    monitoring:{title:"Operational Monitoring",description:"Live platform activity, health signals and operational exceptions.",icon:Activity,primaryAction:"Inspect activity",records:[
      {id:"MON-3201",title:"Marketplace review queue increased",description:"18 new listings entered review in the last hour.",status:"Attention",fields:{Area:"Local Market",Signal:"Review queue",Volume:"46 pending",Change:"+18 in 1 hour","Last updated":"2 minutes ago",Owner:"Marketplace operations"}},
      {id:"MON-3198",title:"Payment processing healthy",description:"Settlement processing is within expected thresholds.",status:"Healthy",fields:{Area:"Payments",Signal:"Settlement success",Volume:"99.4%",Change:"+0.2% today","Last updated":"4 minutes ago",Owner:"Financial operations"}},
      {id:"MON-3192",title:"Errand matching delay",description:"Five requests have waited longer than the target window.",status:"Attention",fields:{Area:"Errands",Signal:"Matching latency",Volume:"5 delayed",Change:"+3 today","Last updated":"7 minutes ago",Owner:"Logistics operations"}},
    ]},
    access:{title:"Admin Access",description:"Administrative accounts, assigned roles, permissions and recent access activity.",icon:Lock,primaryAction:"View permissions",secondaryAction:"Suspend access",records:[
      {id:"ADM-001",title:"Sarah Mensah",description:"Super Administrator",status:"Active",fields:{Email:"sarah@hivorr.com",Role:"Super Admin",Permissions:"All administrative modules","Last sign-in":"Jul 15, 2026 · 08:12","MFA status":"Enabled","Created by":"System owner"}},
      {id:"ADM-014",title:"Michael Okafor",description:"Marketplace Operations Admin",status:"Active",fields:{Email:"michael@hivorr.com",Role:"Marketplace Operations",Permissions:"Marketplace, sellers, categories","Last sign-in":"Jul 15, 2026 · 07:48","MFA status":"Enabled","Created by":"Sarah Mensah"}},
      {id:"ADM-021",title:"Nadia Boateng",description:"Support Administrator",status:"Invited",fields:{Email:"nadia@hivorr.com",Role:"Support Admin",Permissions:"Support, disputes, user read-only","Last sign-in":"Not yet signed in","MFA status":"Required","Created by":"Sarah Mensah"}},
    ]},
    notifications:{title:"Notification Management",description:"Platform messages, recipients, delivery status and history.",icon:Bell,primaryAction:"View delivery",secondaryAction:"Resend",records:[
      {id:"NTF-4401",title:"Marketplace policy update",description:"Policy announcement to active sellers",status:"Delivered",fields:{Recipients:"1,284 sellers",Channel:"Email + in-app",Sent:"Jul 14, 2026 · 12:00",Delivered:"1,248",Failed:"36",Owner:"Marketplace operations"}},
      {id:"NTF-4398",title:"Scheduled maintenance",description:"Platform-wide maintenance notice",status:"Scheduled",fields:{Recipients:"All active users",Channel:"In-app + push",Scheduled:"Jul 18, 2026 · 01:00",Template:"Maintenance v3",Owner:"Platform operations",Approval:"Approved"}},
      {id:"NTF-4390",title:"Verification reminder",description:"Reminder to pending professional applicants",status:"Delivered",fields:{Recipients:"27 professionals",Channel:"Email",Sent:"Jul 13, 2026 · 09:30",Delivered:"26",Failed:"1",Owner:"Verification team"}},
    ]},
    reports:{title:"Report Management",description:"User-submitted and platform-generated reports requiring investigation.",icon:FileText,primaryAction:"Investigate",secondaryAction:"Resolve",records:[
      {id:"RPT-1824",title:"Off-platform payment request",description:"Professional allegedly requested direct payment.",status:"Open",fields:{Reporter:"TechVentures Africa",Subject:"Professional account · FH",Job:"Office Renovation & Electrical",Submitted:"Jul 15, 2026",Evidence:"2 message screenshots",Assignee:"Trust & Safety"}},
      {id:"RPT-1819",title:"Misleading product description",description:"Buyer reported material mismatch.",status:"Investigating",fields:{Reporter:"Adaeze Okafor",Subject:"Indigo Carry Basket",Order:"#HV-20392",Submitted:"Jul 14, 2026",Evidence:"3 product photos",Assignee:"Marketplace support"}},
      {id:"RPT-1804",title:"Repeated delivery cancellation",description:"Platform-generated provider reliability report.",status:"Resolved",fields:{Reporter:"Platform monitoring",Subject:"SwiftDrop Lagos",Related:"3 delivery assignments",Submitted:"Jul 10, 2026",Resolution:"Provider warning issued",Assignee:"Logistics operations"}},
    ]},
    disputes:{title:"Dispute Management",description:"Cases involving users, jobs, orders or payments, with evidence and resolution history.",icon:AlertCircle,primaryAction:"View case",secondaryAction:"Resolve",records:[
      {id:"DSP-904",title:"Milestone delivery disagreement",description:"Client disputes completion of development milestone.",status:"Open",fields:{Client:"TechVentures Africa",Professional:"Amara Diallo",Job:"Senior React Developer",Amount:"$1,750 in escrow",Opened:"Jul 14, 2026",Evidence:"4 files · 12 messages"}},
      {id:"DSP-898",title:"Product condition complaint",description:"Buyer and seller disagree on return eligibility.",status:"Mediation",fields:{Buyer:"Adaeze Okafor",Seller:"Zuri Craft House",Order:"#HV-20392",Amount:"₦18,500",Opened:"Jul 12, 2026",Evidence:"5 photos · invoice"}},
      {id:"DSP-881",title:"Cancelled delivery fee",description:"Requester disputed cancellation fee.",status:"Resolved",fields:{Requester:"Tomi Adebayo",Provider:"Kemi Adisa",Request:"ER-0981",Amount:"₦1,200",Opened:"Jul 06, 2026",Resolution:"Fee refunded"}},
    ]},
    support:{title:"Support Management",description:"Platform-wide enquiries, complaints, support requests, disputes and resolution activity.",icon:MessageCircle,primaryAction:"View request",secondaryAction:"Resolve",records:[
      {id:"SUP-2408",title:"Unable to withdraw professional earnings",description:"Professional reports a payout account validation issue.",status:"Open",fields:{Requester:"Amara Diallo",Channel:"In-app support",Priority:"High",Category:"Payments & withdrawals",Created:"Jul 15, 2026 · 09:42",Assignee:"Financial support"}},
      {id:"SUP-2403",title:"Order arrived with missing item",description:"Buyer requests help with a Local Market order.",status:"Investigating",fields:{Requester:"Adaeze Okafor",Channel:"Email",Priority:"Medium",Category:"Order complaint",Created:"Jul 14, 2026 · 16:18",Assignee:"Marketplace support"}},
      {id:"SUP-2396",title:"Delivery cancellation dispute",description:"Errand requester disputes a provider cancellation.",status:"Escalated",fields:{Requester:"Tomi Adebayo",Channel:"In-app support",Priority:"High",Category:"Dispute",Created:"Jul 13, 2026 · 11:06",Assignee:"Trust & Safety"}},
      {id:"SUP-2381",title:"How to update business verification",description:"Seller requests guidance on replacing an expired document.",status:"Resolved",fields:{Requester:"Nova Gadget Store",Channel:"Help centre",Priority:"Low",Category:"Verification enquiry",Created:"Jul 11, 2026",Resolution:"Guidance sent"}},
    ]},
    security:{title:"Security Logs",description:"Administrative actions, login events, access records and account-security monitoring.",icon:Shield,primaryAction:"Inspect event",secondaryAction:"Escalate",records:[
      {id:"SEC-8821",title:"Super Admin configuration change",description:"Payment settlement schedule updated.",status:"Recorded",fields:{Actor:"Sarah Mensah · Super Admin",Event:"Configuration update",IP:"197.210.54.18",Device:"Chrome · macOS",Time:"Jul 15, 2026 · 09:18",Outcome:"Successful"}},
      {id:"SEC-8818",title:"Failed administrator login attempts",description:"Five unsuccessful attempts were detected.",status:"Attention",fields:{Actor:"Unknown",Event:"Authentication failure",IP:"102.89.42.11",Device:"Unknown browser",Time:"Jul 15, 2026 · 08:54",Outcome:"Account temporarily locked"}},
      {id:"SEC-8812",title:"Marketplace record suspended",description:"Administrator suspended a flagged seller listing.",status:"Recorded",fields:{Actor:"Michael Okafor · Marketplace Admin",Event:"Moderation action",IP:"154.113.18.62",Device:"Edge · Windows",Time:"Jul 15, 2026 · 08:32",Outcome:"Successful"}},
      {id:"SEC-8804",title:"New support administrator access",description:"Role assignment and MFA enrolment completed.",status:"Recorded",fields:{Actor:"Sarah Mensah · Super Admin",Event:"Admin permission change",IP:"197.210.54.18",Device:"Chrome · macOS",Time:"Jul 14, 2026 · 17:05",Outcome:"Successful"}},
    ]},
  };
  return configs[module];
}

function AdminModulePage({ module,bp }: { module:AdminRecordModule;bp:BP }) {
  const config=getAdminModuleData(module);
  const [records,setRecords]=useState(()=>config.records);
  const [query,setQuery]=useState("");
  const [viewing,setViewing]=useState<AdminModuleRecord|null>(null);
  const [action,setAction]=useState<{record:AdminModuleRecord;label:string}|null>(null);
  const [audit,setAudit]=useState("");
  const Icon=config.icon;
  const filtered=records.filter(record=>`${record.title} ${record.description} ${Object.values(record.fields).join(" ")}`.toLowerCase().includes(query.toLowerCase()));
  const confirmAction=()=>{if(!action)return;const nextStatus=action.label.toLowerCase().includes("resolve")?"Resolved":action.label.toLowerCase().includes("approve")?"Approved":action.label.toLowerCase().includes("reinstate")?"Active":action.label.toLowerCase().includes("reject")?"Rejected":action.label.toLowerCase().includes("suspend")||action.label.toLowerCase().includes("hold")?"Suspended":action.record.status;setRecords(items=>items.map(item=>item.id===action.record.id?{...item,status:nextStatus}:item));setAudit(`${action.label} recorded for ${action.record.id} by Super Admin · just now`);setAction(null);};
  return <div style={{ flex:1,overflowY:"auto",padding:bp.isMobile?"16px 16px 90px":28 }}><div style={{ maxWidth:1200,margin:"0 auto" }}>
    <div style={{ display:"flex",gap:13,alignItems:"flex-start" }}><div style={{ width:46,height:46,borderRadius:14,background:C.purpleLight,display:"flex",alignItems:"center",justifyContent:"center",flexShrink:0 }}><Icon size={20} color={C.purple}/></div><div><Pill label={["access","notifications","reports","disputes","support","security"].includes(module)?"PLATFORM ADMIN":"DASHBOARD MANAGEMENT"} color={C.purple} bg={C.purpleLight}/><h2 style={{ fontFamily:"'Plus Jakarta Sans',sans-serif",fontSize:22,fontWeight:800,color:C.ink,marginTop:8 }}>{config.title}</h2><p style={{ fontSize:11,color:C.gray,lineHeight:1.5,marginTop:4 }}>{config.description}</p></div></div>
    <div style={{ display:"grid",gridTemplateColumns:bp.isMobile?"repeat(2,1fr)":"repeat(4,1fr)",gap:10,marginTop:18 }}>{[["Total records",String(records.length)],["Active / open",String(records.filter(record=>["Active","Open","Published","Healthy"].includes(record.status)).length)],["Needs attention",String(records.filter(record=>["Pending","Pending review","Attention","Flagged","In review"].includes(record.status)).length)],["Updated","Just now"]].map(([label,value],index)=><div key={label} style={{ background:C.card,border:`1px solid ${C.border}`,borderRadius:13,padding:12 }}><p style={{ fontSize:9,color:C.muted }}>{label}</p><p style={{ fontSize:index===3?12:19,fontWeight:800,color:index===2?C.orange:C.ink,marginTop:4 }}>{value}</p></div>)}</div>
    <Card padding={0} style={{ marginTop:15,overflow:"hidden" }}><div style={{ padding:13,borderBottom:`1px solid ${C.border}`,display:"flex",gap:9,alignItems:"center",flexWrap:"wrap" }}><div style={{ flex:1,minWidth:220,display:"flex",gap:7,alignItems:"center",background:"#F4F6FB",padding:"9px 12px",borderRadius:10 }}><Search size={13} color={C.muted}/><input value={query} onChange={event=>setQuery(event.target.value)} placeholder={`Search ${config.title.toLowerCase()}`} style={{ border:0,outline:0,background:"transparent",width:"100%",fontSize:11 }}/></div><Pill label={`${filtered.length} records`} color={C.primary} bg={C.primaryLight}/></div><div style={{ overflowX:"auto" }}><table style={{ width:"100%",borderCollapse:"collapse",minWidth:760 }}><thead><tr style={{ background:"#F8F9FC" }}>{["Reference / record","Key information","Status","Administrative actions"].map(label=><th key={label} style={{ padding:12,textAlign:"left",fontSize:10,color:C.muted }}>{label}</th>)}</tr></thead><tbody>{filtered.map(record=><tr key={record.id} style={{ borderTop:`1px solid ${C.border}` }}><td style={{ padding:12 }}><p style={{ fontSize:11,fontWeight:800,color:C.ink }}>{record.title}</p><p style={{ fontSize:9,color:C.muted,marginTop:3 }}>{record.id}</p></td><td style={{ padding:12,maxWidth:360 }}><p style={{ fontSize:10,color:C.gray,lineHeight:1.45 }}>{record.description}</p><p style={{ fontSize:9,color:C.muted,marginTop:4 }}>{Object.entries(record.fields).slice(0,2).map(([label,value])=>`${label}: ${value}`).join(" · ")}</p></td><td style={{ padding:12 }}><Pill label={record.status} color={["Active","Approved","Completed","Delivered","Healthy","Resolved","Published"].includes(record.status)?C.green:["Rejected","Suspended","Flagged"].includes(record.status)?C.red:C.orange} bg={["Active","Approved","Completed","Delivered","Healthy","Resolved","Published"].includes(record.status)?C.greenLight:["Rejected","Suspended","Flagged"].includes(record.status)?C.redLight:C.orangeLight}/></td><td style={{ padding:12 }}><div style={{ display:"flex",gap:5 }}><Btn size="sm" variant="secondary" onClick={()=>setViewing(record)}>{config.primaryAction}</Btn>{(["jobs","verification","requests"] as AdminRecordModule[]).includes(module)&&!["Approved","Published","Completed"].includes(record.status)&&<Btn size="sm" onClick={()=>setAction({record,label:"Approve"})}>Approve</Btn>}{config.secondaryAction&&<Btn size="sm" variant="danger" onClick={()=>setAction({record,label:record.status==="Suspended"?"Reinstate":config.secondaryAction!})}>{record.status==="Suspended"?"Reinstate":config.secondaryAction}</Btn>}</div></td></tr>)}</tbody></table></div></Card>
    {audit&&<div style={{ background:C.greenLight,borderRadius:12,padding:11,marginTop:11,display:"flex",gap:8 }}><CheckCircle size={15} color={C.green}/><p style={{ fontSize:10,color:C.green }}>{audit}</p></div>}
    {viewing&&<PrototypeDialog title={viewing.title} eyebrow={`${config.title.toUpperCase()} · ${viewing.id}`} onClose={()=>setViewing(null)} maxWidth={680} footer={<><Btn variant="ghost" onClick={()=>setViewing(null)}>Close</Btn><Btn onClick={()=>{setViewing(null);setAudit(`Detail review recorded for ${viewing.id} · just now`);}}>Record review</Btn></>}><div style={{ display:"flex",flexDirection:"column",gap:13 }}><p style={{ fontSize:11,color:C.gray,lineHeight:1.6 }}>{viewing.description}</p><div style={{ display:"grid",gridTemplateColumns:bp.isMobile?"1fr":"1fr 1fr",gap:8 }}>{Object.entries(viewing.fields).map(([label,value])=><div key={label} style={{ background:"#F8F9FC",borderRadius:11,padding:11 }}><p style={{ fontSize:9,color:C.muted }}>{label}</p><p style={{ fontSize:11,fontWeight:700,color:C.ink,marginTop:3 }}>{value}</p></div>)}</div><div style={{ background:C.purpleLight,borderRadius:11,padding:11,display:"flex",gap:8 }}><Shield size={15} color={C.purple}/><p style={{ fontSize:10,color:C.gray,lineHeight:1.5 }}>Access and actions are limited by the signed-in administrator's assigned permissions. Reviews are added to the prototype audit trail.</p></div></div></PrototypeDialog>}
    {action&&<PrototypeDialog title={`${action.label} this record?`} eyebrow="PERMISSION CHECK · CONFIRMATION" onClose={()=>setAction(null)} footer={<><Btn variant="ghost" onClick={()=>setAction(null)}>Cancel</Btn><Btn variant={action.label==="Reinstate"?"primary":"danger"} onClick={confirmAction}>Confirm {action.label.toLowerCase()}</Btn></>}><div style={{ background:action.label==="Reinstate"?C.greenLight:C.redLight,borderRadius:12,padding:13 }}><p style={{ fontSize:11,fontWeight:800,color:C.ink }}>{action.record.title}</p><p style={{ fontSize:10,color:C.gray,lineHeight:1.55,marginTop:4 }}>This administrative action will update the prototype record and append an audit entry.</p></div></PrototypeDialog>}
  </div></div>;
}

function AdminCategoryManagement({ bp, categories, setCategories, onBack }: { bp: BP; categories: SellerCategory[]; setCategories: React.Dispatch<React.SetStateAction<SellerCategory[]>>; onBack?:()=>void }) {
  const [query,setQuery]=useState("");
  const [selectedId,setSelectedId]=useState(categories[0]?.id ?? "");
  const [editor,setEditor]=useState<{type:"category"|"subcategory";mode:"create"|"edit";categoryId?:string;subcategoryId?:string;name:string;description:string}|null>(null);
  const [confirm,setConfirm]=useState<{type:"category"|"subcategory";categoryId:string;subcategoryId?:string;name:string;next:boolean}|null>(null);
  const sorted=[...categories].sort((a,b)=>a.order-b.order);
  const visible=sorted.filter(category=>category.name.toLowerCase().includes(query.toLowerCase())||category.subcategories.some(subcategory=>subcategory.name.toLowerCase().includes(query.toLowerCase())));
  const selected=categories.find(category=>category.id===selectedId) ?? categories[0];
  const saveEditor=()=>{
    if(!editor?.name.trim())return;
    if(editor.type==="category"){
      if(editor.mode==="create"){
        const id=`category-${Date.now()}`;
        setCategories(items=>[...items,{id,name:editor.name.trim(),description:editor.description.trim(),active:true,order:Math.max(0,...items.map(item=>item.order))+1,usage:0,subcategories:[]}]);
        setSelectedId(id);
      }else setCategories(items=>items.map(item=>item.id===editor.categoryId?{...item,name:editor.name.trim(),description:editor.description.trim()}:item));
    }else if(editor.mode==="create"){
      setCategories(items=>items.map(item=>item.id===editor.categoryId?{...item,subcategories:[...item.subcategories,{id:`subcategory-${Date.now()}`,name:editor.name.trim(),description:editor.description.trim(),active:true,usage:0}]}:item));
    }else setCategories(items=>items.map(item=>item.id===editor.categoryId?{...item,subcategories:item.subcategories.map(subcategory=>subcategory.id===editor.subcategoryId?{...subcategory,name:editor.name.trim(),description:editor.description.trim()}:subcategory)}:item));
    setEditor(null);
  };
  const applyStatus=()=>{
    if(!confirm)return;
    setCategories(items=>items.map(item=>item.id!==confirm.categoryId?item:confirm.type==="category"?{...item,active:confirm.next}:{...item,subcategories:item.subcategories.map(subcategory=>subcategory.id===confirm.subcategoryId?{...subcategory,active:confirm.next}:subcategory)}));
    setConfirm(null);
  };
  const moveCategory=(id:string,direction:-1|1)=>{
    const ordered=[...categories].sort((a,b)=>a.order-b.order);
    const index=ordered.findIndex(category=>category.id===id),target=index+direction;
    if(index<0||target<0||target>=ordered.length)return;
    const currentOrder=ordered[index].order;
    ordered[index]={...ordered[index],order:ordered[target].order};
    ordered[target]={...ordered[target],order:currentOrder};
    setCategories(ordered);
  };
  return <div style={{ flex:1,overflowY:"auto",padding:bp.isMobile?"16px 16px 80px":28 }}><div style={{ maxWidth:1200,margin:"0 auto" }}>
    <div style={{ display:"flex",justifyContent:"space-between",alignItems:"flex-end",gap:14,flexWrap:"wrap" }}><div>{onBack&&<button onClick={onBack} style={{ display:"flex",alignItems:"center",gap:5,fontSize:11,color:C.gray,marginBottom:9 }}><ArrowLeft size={13}/>Dashboard management</button>}<Pill label="SUPER ADMIN · MARKETPLACE" color={C.purple} bg={C.purpleLight}/><h2 style={{ fontFamily:"'Plus Jakarta Sans',sans-serif",fontWeight:800,fontSize:22,color:C.ink,marginTop:9 }}>Seller product categories</h2><p style={{ fontSize:13,color:C.muted,marginTop:4 }}>Control the taxonomy available in every seller create and edit form.</p></div><Btn onClick={()=>setEditor({type:"category",mode:"create",name:"",description:""})} icon={<Plus size={14}/>}>New category</Btn></div>
    <div style={{ display:"grid",gridTemplateColumns:bp.isDesktop?".8fr 1.2fr":"1fr",gap:18,marginTop:20 }}>
      <Card padding={0}><div style={{ padding:14,borderBottom:`1px solid ${C.border}` }}><div style={{ display:"flex",gap:8,alignItems:"center",background:"#F4F6FB",borderRadius:11,padding:"9px 12px" }}><Search size={14} color={C.muted}/><input value={query} onChange={event=>setQuery(event.target.value)} placeholder="Search categories" style={{ border:0,outline:0,background:"transparent",width:"100%",fontSize:12 }}/></div></div><div style={{ maxHeight:560,overflowY:"auto" }}>{visible.map((category,index)=><button key={category.id} onClick={()=>setSelectedId(category.id)} style={{ width:"100%",display:"flex",alignItems:"center",gap:11,padding:"13px 15px",borderTop:index?`1px solid ${C.border}`:"none",background:selected?.id===category.id?C.primaryLight:C.card,textAlign:"left" }}><div style={{ width:34,height:34,borderRadius:10,background:category.active?C.greenLight:"#F4F6FB",display:"flex",alignItems:"center",justifyContent:"center" }}><Layers size={15} color={category.active?C.green:C.muted}/></div><div style={{ flex:1,minWidth:0 }}><p style={{ fontSize:12,fontWeight:800,color:C.ink,overflow:"hidden",textOverflow:"ellipsis",whiteSpace:"nowrap" }}>{category.name}</p><p style={{ fontSize:10,color:C.muted,marginTop:3 }}>{category.subcategories.length} subcategories · {category.usage.toLocaleString()} listings</p></div><Pill label={category.active?"Active":"Inactive"} color={category.active?C.green:C.muted} bg={category.active?C.greenLight:"#F4F6FB"}/></button>)}</div></Card>
      {selected&&<Card><div style={{ display:"flex",justifyContent:"space-between",alignItems:"flex-start",gap:12,flexWrap:"wrap" }}><div><div style={{ display:"flex",gap:7,alignItems:"center" }}><h3 style={{ fontSize:17,fontWeight:800,color:C.ink }}>{selected.name}</h3><Pill label={selected.active?"ACTIVE":"INACTIVE"} color={selected.active?C.green:C.muted} bg={selected.active?C.greenLight:"#F4F6FB"}/></div><p style={{ fontSize:11,color:C.gray,marginTop:5 }}>{selected.description||"No category description has been added."}</p><p style={{ fontSize:10,color:C.muted,marginTop:4 }}>{selected.usage.toLocaleString()} seller listings use this category · Display position {selected.order}</p></div><div style={{ display:"flex",gap:6,flexWrap:"wrap" }}><Btn size="sm" variant="ghost" onClick={()=>moveCategory(selected.id,-1)}>Move up</Btn><Btn size="sm" variant="ghost" onClick={()=>moveCategory(selected.id,1)}>Move down</Btn><Btn size="sm" variant="secondary" onClick={()=>setEditor({type:"category",mode:"edit",categoryId:selected.id,name:selected.name,description:selected.description??""})} icon={<Edit3 size={12}/>}>Edit</Btn><Btn size="sm" variant={selected.active?"danger":"secondary"} onClick={()=>setConfirm({type:"category",categoryId:selected.id,name:selected.name,next:!selected.active})}>{selected.active?"Deactivate":"Activate"}</Btn></div></div>
        <div style={{ display:"grid",gridTemplateColumns:"repeat(3,1fr)",gap:9,marginTop:18 }}>{[["Listings",selected.usage.toLocaleString()],["Active subcategories",String(selected.subcategories.filter(subcategory=>subcategory.active).length)],["Total subcategories",String(selected.subcategories.length)]].map(([label,value])=><div key={label} style={{ background:"#F8F9FC",borderRadius:12,padding:11,minWidth:0 }}><p style={{ fontSize:9,color:C.muted }}>{label}</p><p style={{ fontSize:16,fontWeight:800,color:C.ink,marginTop:3 }}>{value}</p></div>)}</div>
        <div style={{ display:"flex",justifyContent:"space-between",alignItems:"center",marginTop:20,paddingBottom:10,borderBottom:`1px solid ${C.border}` }}><div><h4 style={{ fontSize:14,fontWeight:800,color:C.ink }}>Subcategories</h4><p style={{ fontSize:10,color:C.muted,marginTop:2 }}>Inactive options disappear from seller dropdowns.</p></div><Btn size="sm" variant="secondary" onClick={()=>setEditor({type:"subcategory",mode:"create",categoryId:selected.id,name:"",description:""})} icon={<Plus size={12}/>}>Add</Btn></div>
        {selected.subcategories.length?selected.subcategories.map((subcategory,index)=><div key={subcategory.id} style={{ display:"flex",alignItems:"center",gap:10,padding:"12px 0",borderTop:index?`1px solid ${C.border}`:"none",flexWrap:bp.isMobile?"wrap":"nowrap" }}><div style={{ flex:1,minWidth:150 }}><p style={{ fontSize:12,fontWeight:700,color:C.ink }}>{subcategory.name}</p><p style={{ fontSize:10,color:C.muted,marginTop:3 }}>{subcategory.description||`${subcategory.usage.toLocaleString()} listings`}</p></div><Pill label={subcategory.active?"Available":"Unavailable"} color={subcategory.active?C.green:C.muted} bg={subcategory.active?C.greenLight:"#F4F6FB"}/><Btn size="sm" variant="ghost" onClick={()=>setEditor({type:"subcategory",mode:"edit",categoryId:selected.id,subcategoryId:subcategory.id,name:subcategory.name,description:subcategory.description??""})}>Edit</Btn><Btn size="sm" variant={subcategory.active?"danger":"secondary"} onClick={()=>setConfirm({type:"subcategory",categoryId:selected.id,subcategoryId:subcategory.id,name:subcategory.name,next:!subcategory.active})}>{subcategory.active?"Deactivate":"Activate"}</Btn></div>):<div style={{ padding:24,textAlign:"center",background:"#F8F9FC",borderRadius:13,marginTop:12 }}><Layers size={22} color={C.muted}/><p style={{ fontSize:12,fontWeight:700,color:C.ink,marginTop:7 }}>No subcategories configured</p><p style={{ fontSize:10,color:C.muted,marginTop:3 }}>The seller form will disable its subcategory field for this category.</p></div>}
      </Card>}
    </div>
    {editor&&<PrototypeDialog title={`${editor.mode==="create"?"Create":"Edit"} ${editor.type}`} eyebrow="ADMIN TAXONOMY" onClose={()=>setEditor(null)} footer={<><Btn variant="ghost" onClick={()=>setEditor(null)}>Cancel</Btn><Btn onClick={saveEditor} disabled={!editor.name.trim()} icon={<Check size={14}/>}>Save</Btn></>}><div style={{ display:"flex",flexDirection:"column",gap:13 }}><Input label={`${editor.type==="category"?"Category":"Subcategory"} name`} value={editor.name} onChange={event=>setEditor({...editor,name:event.target.value})}/><Input label="Description" value={editor.description} onChange={event=>setEditor({...editor,description:event.target.value})} placeholder="Explain what belongs in this category"/><div style={{ background:C.primaryLight,borderRadius:12,padding:12,display:"flex",gap:8 }}><Info size={16} color={C.primary}/><p style={{ fontSize:10,color:C.gray,lineHeight:1.5 }}>Once active, this name automatically appears in the seller dropdown. Sellers cannot create taxonomy values.</p></div></div></PrototypeDialog>}
    {confirm&&<PrototypeDialog title={`${confirm.next?"Activate":"Deactivate"} ${confirm.name}?`} eyebrow="PERMISSION REQUIRED · SUPER ADMIN" onClose={()=>setConfirm(null)} footer={<><Btn variant="ghost" onClick={()=>setConfirm(null)}>Cancel</Btn><Btn variant={confirm.next?"primary":"danger"} onClick={applyStatus}>{confirm.next?"Confirm activation":"Confirm deactivation"}</Btn></>}><div style={{ background:confirm.next?C.greenLight:C.redLight,borderRadius:14,padding:14,display:"flex",gap:10 }}><AlertCircle size={18} color={confirm.next?C.green:C.red}/><p style={{ fontSize:11,color:C.gray,lineHeight:1.6 }}>{confirm.next?"This option will become available for new and edited seller listings.":"This option will be removed from seller selection immediately. Existing listing records remain visible for oversight."}</p></div></PrototypeDialog>}
  </div></div>;
}

type AdminWorkspaceId = "buyer" | "client" | "errand" | "seller" | "professional" | "logistics";

const adminWorkspaceConfig: Record<AdminWorkspaceId,{title:string;activity:string;description:string;color:string;bg:string;icon:LucideIcon;tabs:string[]}> = {
  buyer:{title:"Buyer Administration",activity:"I Want to Buy",description:"Manage Local Market discovery, products, purchases and buyer activity from one workspace.",color:C.primary,bg:C.primaryLight,icon:ShoppingBag,tabs:["Overview","Local Market","Categories","Products & sellers","Reviews","Orders","Payments","Reports"]},
  client:{title:"Client Administration",activity:"I Want to Hire",description:"Oversee client accounts, job posts, hiring, applications and client transactions.",color:C.purple,bg:C.purpleLight,icon:Users,tabs:["Overview","Client accounts","Job posts","Hiring","Applications","Verification","Payments","Reports"]},
  errand:{title:"Errand Requester Administration",activity:"Send an Errand",description:"Monitor requester accounts, requests, configuration, assignments, completion and transactions.",color:C.orange,bg:C.orangeLight,icon:Navigation,tabs:["Overview","Requester accounts","Requests","Categories","Monitoring","Assignments & completion","Payments","Reports"]},
  seller:{title:"Seller Administration",activity:"I Want to Sell",description:"Manage sellers, products, taxonomy, inventory, orders, invoices, earnings and sales performance.",color:C.purple,bg:C.purpleLight,icon:Store,tabs:["Overview","Seller accounts","Products","Categories","Inventory","Orders","Invoices","Earnings","Reports"]},
  professional:{title:"Professional Administration",activity:"I Want to Offer My Services",description:"Oversee professional accounts, approvals, services, evidence, applications and earnings.",color:C.green,bg:C.greenLight,icon:Award,tabs:["Overview","Accounts","Verification","Service categories","Service listings","Evidence","Engagements","Earnings","Reports"]},
  logistics:{title:"Logistics Provider Administration",activity:"I Want to Provide Logistics",description:"Manage providers, verification, delivery work, configuration, history and earnings.",color:C.orange,bg:C.orangeLight,icon:Truck,tabs:["Overview","Provider accounts","Verification","Requests","Active deliveries","History","Configuration","Earnings","Reports"]},
};

function AdminActivityWorkspace({ workspace, bp, goTo, categories, setCategories }: { workspace:AdminWorkspaceId;bp:BP;goTo:(screen:Screen)=>void;categories:SellerCategory[];setCategories:React.Dispatch<React.SetStateAction<SellerCategory[]>> }) {
  const config=adminWorkspaceConfig[workspace];
  const [tab,setTab]=useState("Overview");
  const [query,setQuery]=useState("");
  const [statusFilter,setStatusFilter]=useState("All");
  const [viewing,setViewing]=useState<{name:string;type:string;status:string}|null>(null);
  const [confirmation,setConfirmation]=useState<{action:string;name:string}|null>(null);
  const [notice,setNotice]=useState("");
  useEffect(()=>{setTab("Overview");setQuery("");setNotice("");},[workspace]);
  const Icon=config.icon;
  const capabilities=config.tabs.filter(item=>item!=="Overview");
  const records=[
    {name:workspace==="buyer"?"Indigo Carry Basket":workspace==="client"?"Senior React Developer":workspace==="errand"?"ER-1042 · Prescription collection":workspace==="seller"?"Zuri Craft House":workspace==="professional"?"Chidi Okonkwo":workspace==="logistics"?"Kemi Adisa":"Record",type:tab,status:"Pending review"},
    {name:workspace==="buyer"?"Order #HV-20481":workspace==="client"?"TechVentures Africa":workspace==="errand"?"ER-1018 · Document delivery":workspace==="seller"?"Handwoven Market Tote":workspace==="professional"?"Amara Diallo":workspace==="logistics"?"Delivery #DL-8388":"Record",type:tab,status:"Active"},
    {name:workspace==="buyer"?"Farm Fresh Produce Box":workspace==="client"?"Brand Identity engagement":workspace==="errand"?"ER-0994 · Tailor collection":workspace==="seller"?"Invoice INV-20481":workspace==="professional"?"Trade evidence review":workspace==="logistics"?"SwiftDrop Lagos":"Record",type:tab,status:"Flagged"},
  ].filter(record=>(statusFilter==="All"||record.status===statusFilter)&&record.name.toLowerCase().includes(query.toLowerCase()));
  const contextualRoute=tab.includes("Categor")?"admin-categories":tab.includes("Payment")||tab.includes("Earning")?"admin-payments":tab.includes("Job")||tab.includes("Hiring")||tab.includes("Application")||tab.includes("Engagement")?"admin-jobs":tab.includes("User")||tab.includes("account")||tab==="Accounts"||tab.includes("Provider")?"admin-users":tab==="Configuration"||tab==="Admin access"?"admin-settings":tab==="Local Market"||tab.includes("Product")||tab.includes("Seller")?"admin-marketplace":null;
  if((workspace==="seller"||workspace==="buyer")&&tab==="Categories") return <div style={{ flex:1,overflowY:"auto" }}><div style={{ padding:bp.isMobile?"14px 16px 0":20,maxWidth:1240,margin:"0 auto" }}><button onClick={()=>setTab("Overview")} style={{ display:"flex",alignItems:"center",gap:6,fontSize:11,fontWeight:700,color:config.color }}><ArrowLeft size={13}/> Back to {config.title}</button></div><AdminCategoryManagement bp={bp} categories={categories} setCategories={setCategories}/></div>;
  const complete=()=>{if(!confirmation)return;setNotice(`${confirmation.action} recorded for ${confirmation.name}.`);setConfirmation(null);};
  return <div style={{ flex:1,overflowY:"auto",padding:bp.isMobile?"16px 16px 90px":28 }}><div style={{ maxWidth:1200,margin:"0 auto" }}>
    <div style={{ display:"flex",alignItems:"flex-start",gap:14 }}><div style={{ width:52,height:52,borderRadius:16,background:config.bg,display:"flex",alignItems:"center",justifyContent:"center",flexShrink:0 }}><Icon size={23} color={config.color}/></div><div style={{ flex:1 }}><Pill label={config.activity.toUpperCase()} color={config.color} bg={config.bg}/><h2 style={{ fontFamily:"'Plus Jakarta Sans',sans-serif",fontWeight:800,fontSize:22,color:C.ink,marginTop:8 }}>{config.title}</h2><p style={{ fontSize:11,color:C.gray,lineHeight:1.55,marginTop:4 }}>{config.description}</p></div></div>
    <div style={{ display:"flex",gap:6,overflowX:"auto",padding:"14px 0 5px",position:"sticky",top:0,zIndex:5,background:C.bg }}>{config.tabs.map(item=><button key={item} onClick={()=>{setTab(item);setNotice("");}} style={{ padding:"8px 12px",borderRadius:18,background:tab===item?config.color:C.card,color:tab===item?"#fff":C.gray,border:`1px solid ${tab===item?config.color:C.border}`,fontSize:10,fontWeight:800,whiteSpace:"nowrap" }}>{item}</button>)}</div>
    {tab==="Overview"?<><div style={{ display:"grid",gridTemplateColumns:bp.isDesktop?"repeat(4,1fr)":"repeat(2,1fr)",gap:11,marginTop:14 }}>{[["Open reviews","14"],["Active records","1,284"],["Exceptions","5"],["30-day activity","+18%"]].map(([label,value],index)=><StatCard key={label} label={label} value={value} icon={[<Clock size={17} color={C.orange}/>,<Activity size={17} color={config.color}/>,<AlertCircle size={17} color={C.red}/>,<TrendingUp size={17} color={C.green}/>][index]} color={[C.orange,config.color,C.red,C.green][index]} bg={[C.orangeLight,config.bg,C.redLight,C.greenLight][index]}/>)}</div><div style={{ display:"grid",gridTemplateColumns:bp.isDesktop?"repeat(3,1fr)":"repeat(2,1fr)",gap:11,marginTop:16 }}>{capabilities.map((item,index)=><button key={item} onClick={()=>setTab(item)} style={{ background:C.card,border:`1px solid ${C.border}`,borderRadius:15,padding:14,textAlign:"left",display:"flex",gap:11,alignItems:"center" }}><div style={{ width:36,height:36,borderRadius:11,background:config.bg,display:"flex",alignItems:"center",justifyContent:"center" }}><Layers size={15} color={config.color}/></div><div style={{ flex:1 }}><p style={{ fontSize:11,fontWeight:800,color:C.ink }}>{item}</p><p style={{ fontSize:9,color:C.muted,marginTop:3 }}>{index%3===0?"Review and manage":"Oversight and reporting"}</p></div><ChevronRight size={14} color={C.muted}/></button>)}</div></>:<>
      <div style={{ display:"flex",justifyContent:"space-between",alignItems:"flex-end",gap:12,marginTop:14,flexWrap:"wrap" }}><div><h3 style={{ fontSize:17,fontWeight:800,color:C.ink }}>{tab}</h3><p style={{ fontSize:10,color:C.muted,marginTop:3 }}>Manage {tab.toLowerCase()} without leaving the {config.title} workspace.</p></div>{contextualRoute&&<Btn size="sm" variant="secondary" onClick={()=>goTo(contextualRoute as Screen)}>Open advanced view</Btn>}</div>
      <Card padding={0} style={{ marginTop:13,overflow:"hidden" }}><div style={{ padding:13,display:"flex",gap:8,borderBottom:`1px solid ${C.border}`,flexWrap:"wrap" }}><div style={{ flex:1,minWidth:190,display:"flex",alignItems:"center",gap:7,background:"#F4F6FB",borderRadius:10,padding:"8px 11px" }}><Search size={13} color={C.muted}/><input value={query} onChange={event=>setQuery(event.target.value)} placeholder={`Search ${tab.toLowerCase()}`} style={{ border:0,outline:0,background:"transparent",width:"100%",fontSize:11 }}/></div><div style={{ display:"flex",gap:5 }}>{["All","Pending review","Active","Flagged"].map(status=><button key={status} onClick={()=>setStatusFilter(status)} style={{ padding:"7px 9px",borderRadius:16,background:statusFilter===status?config.bg:C.card,color:statusFilter===status?config.color:C.gray,fontSize:9,fontWeight:700 }}>{status}</button>)}</div></div><div style={{ overflowX:"auto" }}><table style={{ width:"100%",borderCollapse:"collapse",minWidth:650 }}><thead><tr style={{ background:"#F8F9FC" }}>{["Record","Management area","Status","Actions"].map(label=><th key={label} style={{ textAlign:"left",padding:11,fontSize:10,color:C.muted }}>{label}</th>)}</tr></thead><tbody>{records.map(record=><tr key={record.name} style={{ borderTop:`1px solid ${C.border}` }}><td style={{ padding:12,fontSize:11,fontWeight:700,color:C.ink }}>{record.name}</td><td style={{ padding:12,fontSize:10,color:C.gray }}>{record.type}</td><td style={{ padding:12 }}><Pill label={record.status} color={record.status==="Active"?C.green:record.status==="Flagged"?C.red:C.orange} bg={record.status==="Active"?C.greenLight:record.status==="Flagged"?C.redLight:C.orangeLight}/></td><td style={{ padding:12 }}><div style={{ display:"flex",gap:5 }}><Btn size="sm" variant="ghost" onClick={()=>setViewing(record)}>View</Btn><Btn size="sm" variant="secondary" onClick={()=>setConfirmation({action:"Approve",name:record.name})}>Approve</Btn>{record.status!=="Active"&&<Btn size="sm" variant="danger" onClick={()=>setConfirmation({action:"Reject",name:record.name})}>Reject</Btn>}</div></td></tr>)}</tbody></table></div></Card></>}
    {notice&&<div style={{ background:C.greenLight,borderRadius:12,padding:12,marginTop:12,display:"flex",gap:8 }}><CheckCircle size={16} color={C.green}/><p style={{ fontSize:10,color:C.green }}>{notice}</p></div>}
    {viewing&&<PrototypeDialog title={viewing.name} eyebrow={`${config.title.toUpperCase()} · ${tab.toUpperCase()}`} onClose={()=>setViewing(null)} footer={<><Btn variant="ghost" onClick={()=>setViewing(null)}>Close</Btn><Btn onClick={()=>{setViewing(null);setNotice(`${viewing.name} marked as reviewed.`);}}>Mark as reviewed</Btn></>}><div style={{ display:"flex",flexDirection:"column",gap:12 }}><div style={{ display:"flex",justifyContent:"space-between",background:"#F8F9FC",borderRadius:12,padding:12 }}><span style={{ fontSize:10,color:C.muted }}>Status</span><Pill label={viewing.status} color={C.orange} bg={C.orangeLight}/></div><p style={{ fontSize:11,color:C.gray,lineHeight:1.6 }}>This record belongs to {viewing.type.toLowerCase()} in the {config.title}. Its activity and audit context are kept together in this detail view.</p></div></PrototypeDialog>}
    {confirmation&&<PrototypeDialog title={`${confirmation.action} this record?`} eyebrow="ADMIN CONFIRMATION" onClose={()=>setConfirmation(null)} footer={<><Btn variant="ghost" onClick={()=>setConfirmation(null)}>Cancel</Btn><Btn variant={confirmation.action==="Approve"?"primary":"danger"} onClick={complete}>Confirm {confirmation.action.toLowerCase()}</Btn></>}><p style={{ fontSize:11,color:C.gray,lineHeight:1.6 }}>{confirmation.name}<br/>This prototype action is permission-gated and does not update a backend.</p></PrototypeDialog>}
  </div></div>;
}

function AdminMarketplace({ bp, goTo }: { bp: BP; goTo: (screen: Screen) => void }) {
  const queue = [{ name: "Indigo Carry Basket", seller: "Zuri Craft House", type: "Product", status: "Pending" }, { name: "Nova Gadget Store", seller: "Tunde Bello", type: "Seller verification", status: "Review" }, { name: "SwiftDrop Lagos", seller: "Kemi Adisa", type: "Logistics provider", status: "Review" }];
  const [reviewing,setReviewing]=useState<(typeof queue)[number]|null>(null);
  return <div style={{ flex: 1, overflowY: "auto", padding: bp.isMobile ? "16px 16px 80px" : 28 }}><div style={{ maxWidth: 1200, margin: "0 auto" }}><div><button onClick={()=>goTo("admin-workspace")} style={{ display:"flex",alignItems:"center",gap:5,fontSize:11,color:C.gray,marginBottom:10 }}><ArrowLeft size={13}/>Activity workspace</button><h2 style={{ fontFamily: "'Plus Jakarta Sans',sans-serif", fontWeight: 800, fontSize: 22, color: C.ink }}>Marketplace oversight</h2><p style={{ fontSize: 13, color: C.muted, marginTop: 4 }}>Products, sellers, categories, orders, and logistics providers</p></div><div style={{ display: "grid", gridTemplateColumns: bp.isMobile ? "repeat(2,1fr)" : "repeat(4,1fr)", gap: 12, marginTop: 20 }}>{[{ l: "Active listings", v: "8,429", i: Store, c: C.primary, b: C.primaryLight }, { l: "Pending review", v: "46", i: Clock, c: C.orange, b: C.orangeLight }, { l: "Verified sellers", v: "1,284", i: CheckCircle, c: C.green, b: C.greenLight }, { l: "Open orders", v: "2,106", i: Package, c: C.purple, b: C.purpleLight }].map(item => <StatCard key={item.l} label={item.l} value={item.v} icon={<item.i size={19} color={item.c} />} color={item.c} bg={item.b} />)}</div><div style={{ display: "grid", gridTemplateColumns: bp.isDesktop ? "1.35fr .65fr" : "1fr", gap: 18, marginTop: 18 }}><Card><div style={{ display: "flex", justifyContent: "space-between", alignItems: "center" }}><h3 style={{ fontSize: 16, fontWeight: 800, color: C.ink }}>Review queue</h3><Btn size="sm" variant="secondary" onClick={()=>goTo("admin-workspace")} icon={<ArrowLeft size={12} />}>Activity workspace</Btn></div><div style={{ marginTop: 12 }}>{queue.map((item, i) => <div key={item.name} style={{ display: "flex", alignItems: "center", gap: 11, padding: "13px 0", borderTop: i ? `1px solid ${C.border}` : "none" }}><div style={{ width: 39, height: 39, borderRadius: 11, background: [C.primaryLight, C.purpleLight, C.greenLight][i], display: "flex", alignItems: "center", justifyContent: "center" }}>{i === 0 ? <Store size={17} color={C.primary} /> : i === 1 ? <Shield size={17} color={C.purple} /> : <Truck size={17} color={C.green} />}</div><div style={{ flex: 1 }}><p style={{ fontSize: 13, fontWeight: 700, color: C.ink }}>{item.name}</p><p style={{ fontSize: 11, color: C.muted, marginTop: 3 }}>{item.type} · {item.seller}</p></div><Pill label={item.status} color={C.orange} bg={C.orangeLight} /><Btn size="sm" onClick={()=>setReviewing(item)}>Review</Btn></div>)}</div></Card><Card><h3 style={{ fontSize: 16, fontWeight: 800, color: C.ink }}>Configuration</h3>{[{ l: "Categories & attributes", i: Layers,screen:"admin-categories" as Screen }, { l: "Listing policies", i: FileText,screen:"admin-settings" as Screen }, { l: "Delivery zones", i: MapPin,screen:"admin-settings" as Screen }, { l: "Fees & commissions", i: DollarSign,screen:"admin-settings" as Screen }].map(item => <button key={item.l} onClick={()=>goTo(item.screen)} style={{ width: "100%", display: "flex", gap: 10, alignItems: "center", padding: "12px 0", borderTop: `1px solid ${C.border}`, color: C.ink, fontSize: 12, fontWeight: 700, textAlign: "left" }}><item.i size={15} color={C.primary} /><span style={{ flex: 1 }}>{item.l}</span><ChevronRight size={14} color={C.muted} /></button>)}</Card></div>{reviewing&&<PrototypeDialog title={reviewing.name} eyebrow="MARKETPLACE REVIEW" onClose={()=>setReviewing(null)} footer={<><Btn variant="ghost" onClick={()=>setReviewing(null)}>Close</Btn><Btn onClick={()=>setReviewing(null)}>Record review</Btn></>}><div style={{ display:"flex",flexDirection:"column",gap:12 }}><div style={{ display:"flex",justifyContent:"space-between",background:"#F8F9FC",borderRadius:12,padding:12 }}><span style={{ fontSize:10,color:C.muted }}>{reviewing.type} · {reviewing.seller}</span><Pill label={reviewing.status} color={C.orange} bg={C.orangeLight}/></div><p style={{ fontSize:11,color:C.gray,lineHeight:1.6 }}>Review product, seller and verification context here. Recording the review updates this prototype only.</p></div></PrototypeDialog>}</div></div>;
}

// ─── Screen Titles ────────────────────────────────────────────────────────────

const TITLES: Record<Screen, string> = {
  splash: "", onboarding: "", login: "", signup: "", otp: "", "role-select": "",
  "forgot-password": "", "reset-sent": "",
  "emp-home": "Dashboard", "emp-discover": "Find Services", "emp-postjob": "Post a Job", "emp-jobs": "My Jobs",
  "emp-applications": "Applications", "emp-chat": "Messages", "emp-payments-overview": "Payments", "emp-wallet": "Client Payment Details", "emp-profile": "Profile & Settings",
  "pro-home": "Dashboard", "pro-discover": "Find Work", "pro-jobs": "My Jobs",
  "pro-chat": "Messages", "pro-earnings-overview": "Earnings", "pro-wallet": "Earnings Analysis", "pro-profile": "Profile",
  "admin-overview": "Overview", "admin-users": "User Management", "admin-jobs": "Job Moderation",
  "admin-payments": "Payments", "admin-marketplace": "Marketplace", "admin-categories": "Seller Categories", "admin-workspace": "Activity Administration", "admin-settings": "Settings",
  "admin-clients":"Client Management","admin-job-management":"Job Management","admin-hiring":"Hiring Management","admin-application-management":"Application Management","admin-verification":"Verification Management","admin-payment-management":"Payment Management","admin-request-management":"Request Management","admin-monitoring":"Monitoring",
  "admin-access":"Admin Access","admin-notifications":"Notifications","admin-reports":"Reports","admin-disputes":"Disputes",
  "admin-support":"Support","admin-security-logs":"Security Logs",
  activities: "Activities", "market-home": "Local Market", "market-browse": "Browse Products", "market-saved": "Saved Products", "market-payments": "Payments", "market-profile": "Profile", "product-detail": "Product Details",
  cart: "Cart", checkout: "Checkout", "order-confirmation": "Order Confirmation", orders: "Orders", "order-detail": "Order Details",
  "errand-home": "Errand Dashboard", "errand-request": "Send an Errand", "errand-review": "Review Errand", "errand-tracking": "Track Errand", "errand-history": "My Errands", "errand-payments": "Payments", "errand-profile": "Profile",
  "seller-home": "Seller Workspace", "seller-products": "Products", "seller-listing": "Create Listing", "seller-orders": "Seller Orders", "seller-invoices": "Invoices", "seller-inventory": "Inventory", "seller-analytics": "Sales Analysis", "seller-earnings": "Earnings", "seller-profile": "Profile",
  "logistics-home": "Logistics", "logistics-requests": "Available Requests", "logistics-active": "Active Assignment", "logistics-history": "Delivery History", "logistics-earnings-overview": "Earnings", "logistics-earnings": "Analysis", "logistics-account-profile": "Profile", "logistics-profile": "Provider Details",
};

const AUTH_SCREENS: Screen[] = ["splash", "onboarding", "login", "signup", "otp", "role-select", "forgot-password", "reset-sent"];

// ─── App Root ─────────────────────────────────────────────────────────────────

export default function App() {
  const [screen, setScreen] = useState<Screen>("splash");
  const [role, setRole] = useState<Role>("employer");
  const [cartCount, setCartCount] = useState(0);
  const [marketCategory, setMarketCategory] = useState("All products");
  const [sellerCategories,setSellerCategories]=useState<SellerCategory[]>(initialSellerCategories);
  const [adminWorkspace,setAdminWorkspace]=useState<AdminWorkspaceId>("buyer");
  const [mobileDrawerOpen, setMobileDrawerOpen] = useState(false);
  const bp = useBreakpoint();
  const { isMobile, isTablet } = bp;
  const goTo = useCallback((s: Screen) => { setScreen(s); setMobileDrawerOpen(false); }, []);
  const browseCategory = useCallback((category: string) => { setMarketCategory(category); goTo("market-browse"); }, [goTo]);

  const isAuth = AUTH_SCREENS.includes(screen);

  if (isAuth) {
    return (
      <>
        <style>{`*{box-sizing:border-box;margin:0;padding:0;}body{font-family:'Inter',sans-serif;}::-webkit-scrollbar{display:none;}*{scrollbar-width:none;-ms-overflow-style:none;}`}</style>
        {screen === "splash" && <SplashScreen onDone={() => goTo("onboarding")} />}
        {screen === "onboarding" && <OnboardingScreen onDone={() => goTo("login")} />}
        {screen === "login" && <LoginScreen goTo={goTo} />}
        {screen === "signup" && <SignupScreen goTo={goTo} />}
        {screen === "otp" && <OTPScreen goTo={goTo} />}
        {screen === "role-select" && <ActivitySelectScreen onSelect={activity => {
          if (activity === "hire") setRole("employer");
          if (activity === "offer-services") setRole("professional");
          goTo(ACTIVITY_DESTINATIONS[activity]);
        }} onAdmin={() => { setRole("admin"); setAdminWorkspace("buyer"); goTo("admin-workspace"); }} />}
        {screen === "forgot-password" && <ForgotPasswordScreen goTo={goTo} />}
        {screen === "reset-sent" && <ResetSentScreen goTo={goTo} />}
      </>
    );
  }

  const marketplaceScreens: Screen[] = ["activities", "market-home", "market-browse", "market-saved", "market-payments", "market-profile", "product-detail", "cart", "checkout", "order-confirmation", "orders", "order-detail", "errand-home", "errand-request", "errand-review", "errand-tracking", "errand-history", "errand-payments", "errand-profile", "seller-home", "seller-products", "seller-listing", "seller-orders", "seller-invoices", "seller-inventory", "seller-analytics", "seller-earnings", "seller-profile", "logistics-home", "logistics-requests", "logistics-active", "logistics-history", "logistics-earnings-overview", "logistics-earnings", "logistics-account-profile", "logistics-profile"];
  if (marketplaceScreens.includes(screen)) {
    return (
      <>
        <style>{`*{box-sizing:border-box;margin:0;padding:0;}body{font-family:'Inter',sans-serif;background:#F0F2F8;}::-webkit-scrollbar{display:none;}*{scrollbar-width:none;-ms-overflow-style:none;}button,input,textarea{font-family:inherit;}`}</style>
        <MarketShell screen={screen} goTo={goTo} cartCount={cartCount}>
          {screen === "activities" && <ActivitiesHub goTo={goTo} bp={bp} />}
          {screen === "market-home" && <MarketHome goTo={goTo} bp={bp} onBrowseCategory={browseCategory} />}
          {screen === "market-browse" && <MarketBrowse goTo={goTo} bp={bp} initialCategory={marketCategory} />}
          {screen === "market-saved" && <MarketSaved goTo={goTo} bp={bp} />}
          {screen === "market-payments" && <UnifiedPayments goTo={goTo} bp={bp} activity="market" />}
          {screen === "market-profile" && <UnifiedProfile goTo={goTo} bp={bp} />}
          {screen === "product-detail" && <ProductDetail goTo={goTo} bp={bp} onAdd={() => setCartCount(1)} />}
          {screen === "cart" && <CartScreen goTo={goTo} bp={bp} />}
          {screen === "checkout" && <CheckoutScreen goTo={goTo} bp={bp} />}
          {screen === "order-confirmation" && <OrderConfirmation goTo={goTo} />}
          {screen === "orders" && <OrdersScreen bp={bp} />}
          {screen === "order-detail" && <OrderDetail goTo={goTo} bp={bp} />}
          {screen === "errand-home" && <ErrandHome goTo={goTo} bp={bp} />}
          {screen === "errand-request" && <ErrandRequest goTo={goTo} bp={bp} />}
          {screen === "errand-review" && <ErrandReview goTo={goTo} bp={bp} />}
          {screen === "errand-tracking" && <ErrandTracking goTo={goTo} bp={bp} />}
          {screen === "errand-history" && <ErrandHistory goTo={goTo} bp={bp} />}
          {screen === "errand-payments" && <UnifiedPayments goTo={goTo} bp={bp} activity="errand" />}
          {screen === "errand-profile" && <UnifiedProfile goTo={goTo} bp={bp} />}
          {screen === "seller-home" && <SellerHome goTo={goTo} bp={bp} categories={sellerCategories} />}
          {screen === "seller-products" && <SellerProducts goTo={goTo} bp={bp} categories={sellerCategories} />}
          {screen === "seller-listing" && <SellerListing goTo={goTo} bp={bp} categories={sellerCategories} />}
          {screen === "seller-orders" && <SellerOrders goTo={goTo} bp={bp} />}
          {screen === "seller-invoices" && <SellerInvoices bp={bp} />}
          {screen === "seller-inventory" && <SellerInventory bp={bp} />}
          {screen === "seller-analytics" && <SellerSalesAnalysis goTo={goTo} bp={bp} />}
          {screen === "seller-earnings" && <UnifiedEarnings goTo={goTo} bp={bp} activity="seller" detailScreen="seller-analytics" detailLabel="Sales Analysis" />}
          {screen === "seller-profile" && <UnifiedProfile goTo={goTo} bp={bp} />}
          {screen === "logistics-home" && <LogisticsHome bp={bp} />}
          {screen === "logistics-requests" && <LogisticsRequests goTo={goTo} bp={bp} />}
          {screen === "logistics-active" && <LogisticsActive bp={bp} />}
          {screen === "logistics-history" && <LogisticsHistory bp={bp} />}
          {screen === "logistics-earnings-overview" && <UnifiedEarnings goTo={goTo} bp={bp} activity="logistics" detailScreen="logistics-earnings" detailLabel="Logistics Analysis" />}
          {screen === "logistics-earnings" && <LogisticsAnalysis bp={bp} />}
          {screen === "logistics-account-profile" && <UnifiedProfile goTo={goTo} bp={bp} detailScreen="logistics-profile" detailLabel="Provider eligibility details" />}
          {screen === "logistics-profile" && <LogisticsProfile bp={bp} />}
        </MarketShell>
      </>
    );
  }

  return (
    <>
      <style>{`
        *{box-sizing:border-box;margin:0;padding:0;}
        body{font-family:'Inter',sans-serif;background:#F0F2F8;}
        ::-webkit-scrollbar{display:none;}
        *{scrollbar-width:none;-ms-overflow-style:none;}
      `}</style>
      <div style={{ display: "flex", height: "100vh", overflow: "hidden" }}>
        {/* Sidebar — tablet (collapsed) + desktop (full) */}
        {!isMobile && <Sidebar screen={screen} role={role} goTo={goTo} collapsed={isTablet&&role!=="admin"} adminWorkspace={adminWorkspace} onAdminWorkspace={workspace=>{setAdminWorkspace(workspace);goTo("admin-workspace");}} />}

        {/* Mobile drawer */}
        {isMobile && mobileDrawerOpen && (
          <>
            <div style={{ position: "fixed", inset: 0, background: "rgba(0,0,0,0.4)", zIndex: 50 }} onClick={() => setMobileDrawerOpen(false)} />
            <div style={{ position: "fixed", left: 0, top: 0, bottom: 0, width: 260, zIndex: 51 }}>
              <Sidebar screen={screen} role={role} goTo={goTo} collapsed={false} adminWorkspace={adminWorkspace} onAdminWorkspace={workspace=>{setAdminWorkspace(workspace);goTo("admin-workspace");}} />
            </div>
          </>
        )}

        <div style={{ flex: 1, display: "flex", flexDirection: "column", overflow: "hidden", minWidth: 0 }}>
          <TopBar title={TITLES[screen]} screen={screen} role={role} goTo={goTo} onMenu={() => setMobileDrawerOpen(v => !v)} />
          <div style={{ flex: 1, display: "flex", overflow: "hidden", background: C.bg }}>
            {/* Employer screens */}
            {screen === "emp-home" && <EmpHome goTo={goTo} bp={bp} />}
            {screen === "emp-discover" && <EmpDiscover goTo={goTo} bp={bp} />}
            {screen === "emp-postjob" && <EmpPostJob goTo={goTo} bp={bp} />}
            {screen === "emp-jobs" && <EmpJobs goTo={goTo} bp={bp} />}
            {screen === "emp-applications" && <EmpApplications goTo={goTo} bp={bp} />}
            {screen === "emp-chat" && <ChatUI chats={empChats} bp={bp} role={role} />}
            {screen === "emp-payments-overview" && <UnifiedPayments goTo={goTo} bp={bp} activity="client" detailScreen="emp-wallet" />}
            {screen === "emp-wallet" && <EmpWallet goTo={goTo} bp={bp} />}
            {screen === "emp-profile" && <EmpProfile goTo={goTo} bp={bp} />}
            {/* Professional screens */}
            {screen === "pro-home" && <ProHome goTo={goTo} bp={bp} />}
            {screen === "pro-discover" && <ProDiscover goTo={goTo} bp={bp} />}
            {screen === "pro-jobs" && <ProJobs goTo={goTo} bp={bp} />}
            {screen === "pro-chat" && <ChatUI chats={proChats} bp={bp} role={role} />}
            {screen === "pro-earnings-overview" && <UnifiedEarnings goTo={goTo} bp={bp} activity="professional" detailScreen="pro-wallet" detailLabel="Earnings Analysis" />}
            {screen === "pro-wallet" && <ProfessionalEarningsAnalysis bp={bp} />}
            {screen === "pro-profile" && <ProProfile goTo={goTo} bp={bp} />}
            {/* Admin screens */}
            {screen === "admin-overview" && <AdminOverview bp={bp} />}
            {screen === "admin-users" && <AdminUsers bp={bp} />}
            {screen === "admin-jobs" && <AdminJobs bp={bp} />}
            {screen === "admin-payments" && <AdminPayments bp={bp} />}
            {screen === "admin-marketplace" && <AdminMarketplace bp={bp} goTo={goTo} />}
            {screen === "admin-categories" && <AdminCategoryManagement bp={bp} categories={sellerCategories} setCategories={setSellerCategories} onBack={()=>goTo("admin-workspace")} />}
            {screen === "admin-workspace" && <AdminActivityWorkspace workspace={adminWorkspace} bp={bp} goTo={goTo} categories={sellerCategories} setCategories={setSellerCategories} />}
            {screen === "admin-settings" && <AdminSettings bp={bp} />}
            {screen === "admin-clients" && <AdminModulePage module="clients" bp={bp} />}
            {screen === "admin-job-management" && <AdminModulePage module="jobs" bp={bp} />}
            {screen === "admin-hiring" && <AdminModulePage module="hiring" bp={bp} />}
            {screen === "admin-application-management" && <AdminModulePage module="applications" bp={bp} />}
            {screen === "admin-verification" && <AdminModulePage module="verification" bp={bp} />}
            {screen === "admin-payment-management" && <AdminModulePage module="payments" bp={bp} />}
            {screen === "admin-request-management" && <AdminModulePage module="requests" bp={bp} />}
            {screen === "admin-monitoring" && <AdminModulePage module="monitoring" bp={bp} />}
            {screen === "admin-access" && <AdminModulePage module="access" bp={bp} />}
            {screen === "admin-notifications" && <AdminModulePage module="notifications" bp={bp} />}
            {screen === "admin-reports" && <AdminModulePage module="reports" bp={bp} />}
            {screen === "admin-disputes" && <AdminModulePage module="disputes" bp={bp} />}
            {screen === "admin-support" && <AdminModulePage module="support" bp={bp} />}
            {screen === "admin-security-logs" && <AdminModulePage module="security" bp={bp} />}
          </div>
        </div>

        {/* Mobile bottom nav */}
        {isMobile && <MobileBottomNav screen={screen} role={role} goTo={goTo} />}
      </div>
    </>
  );
}
