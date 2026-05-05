# Jenkins controller có plugin đóng gói sẵn — cluster không cần init tải plugin mỗi lần pod lên.
# Build & push Hub (chạy từ ROOT repo go-micro):
#   docker build -t minhtri1612/jenkins-custom:2.492.3-lts-jdk17-pkg1 -f jenkins/Dockerfile jenkins
# Hoặc đã cd vào thư mục jenkins/:
#   docker build -t minhtri1612/jenkins-custom:2.492.3-lts-jdk17-pkg1 -f Dockerfile .
#   docker push minhtri1612/jenkins-custom:2.492.3-lts-jdk17-pkg1
# Kind (không qua Hub): kind load docker-image minhtri1612/jenkins-custom:2.492.3-lts-jdk17-pkg1 --name <cluster>
# Core LTS đủ cho transitive plugins hiện tại (json-api/gson-api… đòi Jenkins ≥ ~2.492).
FROM jenkins/jenkins:2.492.3-lts-jdk17

USER jenkins

COPY --chown=jenkins:jenkins plugins.txt /usr/share/jenkins/ref/plugins.txt

# Cài vào ref — entrypoint copy vào JENKINS_HOME khi PVC trống / thiếu plugin (theo README jenkinsci/docker).
RUN jenkins-plugin-cli -f /usr/share/jenkins/ref/plugins.txt
