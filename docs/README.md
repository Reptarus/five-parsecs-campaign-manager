# Five Parsecs Campaign Manager Documentation

Welcome to the comprehensive documentation for the Five Parsecs Campaign Manager - a digital adaptation of the "Five Parsecs from Home" tabletop RPG by Modiphius Entertainment.

## 🚀 Quick Links

- **[Quick Start Guide](QUICK_START.md)** - Get up and running in 5 minutes
- **[Project Status](project_status.md)** - Current development state (95% complete)
- **[Architecture Guide](technical/ARCHITECTURE.md)** - System design and patterns
- **[Deployment Guide](releases/DEPLOYMENT_GUIDE.md)** - Production deployment instructions
- **[API Reference](developer/API_REFERENCE.md)** - Complete API documentation

## 📊 Project Overview

The Five Parsecs Campaign Manager is a production-ready digital companion for the tabletop RPG, featuring:

- **Complete Campaign Creation** - 6-step workflow with validation
- **Story Track System** - Dynamic narrative generation
- **Battle Events System** - Combat encounter management
- **Digital Dice System** - Visual dice rolling interface
- **Character Management** - Full crew creation and progression
- **Save System** - Auto-save with cloud sync support

### Recent Achievements
- ✅ **Campaign Creation Refactoring** - 57% code reduction using Coordinator Pattern
- ✅ **Production Features** - Analytics, Accessibility, Migration systems integrated
- ✅ **100% Test Coverage** - Critical paths fully tested
- ✅ **Zero Linter Errors** - Clean, maintainable codebase

## 🏗️ Architecture Highlights

The project implements modern software architecture patterns:

```
Coordinator Pattern → Clean UI orchestration
Panel Self-Management → Autonomous components  
State Management → Centralized validation
Security Layer → Input sanitization
Analytics Integration → User behavior tracking
```

See the [Architecture Guide](technical/ARCHITECTURE.md) for detailed information.

## 📁 Documentation Structure

```
docs/
├── QUICK_START.md                 # Developer onboarding
├── project_status.md              # Current development state
├── technical/
│   ├── ARCHITECTURE.md           # System design documentation
│   └── data_architecture.md      # Data flow and storage
├── developer/
│   ├── API_REFERENCE.md          # API documentation
│   └── TESTING_GUIDE.md          # Testing strategies
├── releases/
│   └── DEPLOYMENT_GUIDE.md       # Production deployment
├── gameplay/
│   └── rules_implementation.md   # Five Parsecs rules
└── archive/
    └── refactoring_plan.md       # Completed refactoring docs
```

## 🎮 Key Features

### Campaign Creation System
- **Coordinator Pattern Implementation** - Lightweight orchestration
- **6 Self-Managing Panels** - Config, Crew, Captain, Ship, Equipment, Review
- **Enterprise-Grade Validation** - Security and business rule enforcement
- **State Persistence** - Automatic saving between steps

### Core Game Systems
- **Story Track** (20/20 tests) - Narrative event generation
- **Battle Events** (22/22 tests) - Combat encounter system
- **Digital Dice** - Visual dice rolling with Five Parsecs rules
- **Character Generation** - Complete with backgrounds and motivations

### Production Features
- **Analytics System** - User behavior tracking and insights
- **Accessibility** - Keyboard navigation and screen reader support
- **Migration System** - Legacy save format upgrades
- **Performance Monitoring** - Real-time metrics dashboard

## 🚀 Getting Started

### For Developers
```bash
# Clone the repository
git clone https://github.com/yourusername/five-parsecs-campaign-manager.git

# Open in Godot 4.4+
# Import project.godot

# Run the project (F5)
# Starts at MainMenu.tscn
```

See the [Quick Start Guide](QUICK_START.md) for detailed setup instructions.

### For Contributors
1. Fork the repository
2. Create a feature branch
3. Make your changes with tests
4. Submit a pull request

See [Contributing Guidelines](developer/CONTRIBUTING.md) for more details.

## 📊 Project Metrics

| Metric | Status |
|--------|--------|
| **Completion** | 95% |
| **Test Coverage** | 100% (critical paths) |
| **Code Quality** | 0 errors, 0 warnings |
| **Performance** | <100ms panel transitions |
| **Architecture** | Production-ready |

## 🛠️ Technology Stack

- **Engine**: Godot 4.4 (GDScript)
- **Architecture**: Coordinator Pattern, Three-tier
- **Testing**: GdUnit4
- **Analytics**: Custom implementation
- **Version Control**: Git with feature branches

## 📋 Development Workflow

1. **Feature Development** - Branch from main
2. **Testing** - Unit and integration tests required
3. **Code Review** - All PRs reviewed
4. **Documentation** - Update relevant docs
5. **Deployment** - Automated via CI/CD

## 🔒 Security

- All user inputs validated through SecurityValidator
- Save files encrypted in production
- API keys stored in environment variables
- Regular security audits performed

## 🌟 Roadmap

### Current Sprint (v1.0.0-alpha)
- [x] Campaign creation refactoring
- [x] Production feature integration
- [ ] Performance optimization
- [ ] Alpha release preparation

### Future Plans (v1.1.0)
- [ ] Multiplayer support
- [ ] Steam Workshop integration
- [ ] Mobile companion app
- [ ] Additional campaign types

## 🤝 Support

- **Documentation**: This repository
- **Bug Reports**: GitHub Issues
- **Feature Requests**: GitHub Discussions
- **Community**: Discord Server (coming soon)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](../LICENSE) file for details.

Five Parsecs from Home is © Modiphius Entertainment Ltd. This is an unofficial digital companion.

## 🙏 Acknowledgments

- **Modiphius Entertainment** - For creating Five Parsecs from Home
- **Godot Community** - For the excellent game engine
- **Contributors** - Everyone who has helped improve this project

---

**Ready to dive in?** Start with the [Quick Start Guide](QUICK_START.md) or check out the [Architecture Documentation](technical/ARCHITECTURE.md).