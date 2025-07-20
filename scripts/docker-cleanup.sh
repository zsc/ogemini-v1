#!/bin/bash
# Docker Cleanup Script: Remove old OGemini Docker images

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${BLUE}🧹 OGemini Docker Cleanup${NC}"
echo "================================"

echo -e "${YELLOW}Removing old Docker images...${NC}"

# Remove old naming convention images
docker image rm ogemini-secure:latest 2>/dev/null && echo -e "${GREEN}✅ Removed ogemini-secure:latest${NC}" || echo -e "${YELLOW}⚠️  ogemini-secure:latest not found${NC}"
docker image rm ogemini:latest 2>/dev/null && echo -e "${GREEN}✅ Removed ogemini:latest${NC}" || echo -e "${YELLOW}⚠️  ogemini:latest not found${NC}"

# Optionally remove current images (uncomment if you want fresh build)
# docker image rm ogemini-built:latest 2>/dev/null && echo -e "${GREEN}✅ Removed ogemini-built:latest${NC}" || echo -e "${YELLOW}⚠️  ogemini-built:latest not found${NC}"
# docker image rm ogemini-base:latest 2>/dev/null && echo -e "${GREEN}✅ Removed ogemini-base:latest${NC}" || echo -e "${YELLOW}⚠️  ogemini-base:latest not found${NC}"

# Remove dangling images
echo -e "${YELLOW}Removing dangling images...${NC}"
DANGLING=$(docker images -f "dangling=true" -q)
if [ -n "$DANGLING" ]; then
    docker rmi $DANGLING && echo -e "${GREEN}✅ Removed dangling images${NC}"
else
    echo -e "${YELLOW}⚠️  No dangling images found${NC}"
fi

echo
echo -e "${GREEN}🎉 Docker cleanup completed!${NC}"
echo
echo -e "${BLUE}Current OGemini images:${NC}"
docker images | grep -E "(ogemini|REPOSITORY)" || echo "No OGemini images found"

echo
echo -e "${BLUE}To rebuild everything from scratch:${NC}"
echo "./scripts/docker-simple.sh"